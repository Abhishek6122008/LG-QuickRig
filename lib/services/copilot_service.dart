import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../core/geo.dart';
import '../data/repositories/credentials_repository.dart';
import 'lg_command_service.dart';
import 'lg_kml_controller.dart';
import 'lg_orbit_controller.dart';

class CopilotException implements Exception {
  final String message;
  const CopilotException(this.message);

  @override
  String toString() => message;
}

/// One transcript entry for the chat UI. [role] is 'user' or 'model'.
class CopilotMessage {
  final String role;
  final String text;
  const CopilotMessage(this.role, this.text);
}

/// Gemini-backed copilot: sends the chat to generateContent with function
/// declarations; when the model answers with a functionCall it is dispatched
/// onto the existing LG services and the result fed back, until the model
/// replies in plain text.
class CopilotService {
  final LGCommandService _commands;
  final LGKMLController _kml;
  final LGOrbitController _orbit;
  final CredentialsRepository _credsRepo;

  // Injectable so tests can drive the whole loop with package:http's
  // MockClient instead of calling Gemini for real.
  final http.Client _http;

  CopilotService(this._commands, this._kml, this._orbit, this._credsRepo,
      {http.Client? client})
      : _http = client ?? http.Client();

  static const _url = 'https://generativelanguage.googleapis.com/v1beta/'
      'models/gemini-3.6-flash:generateContent';

  /// What the chat sheet renders. Survives sheet close/reopen because this
  /// service is a singleton.
  final List<CopilotMessage> transcript = [];

  /// Raw Gemini contents (user/model turns including functionCall and
  /// functionResponse parts) — the API needs these verbatim as context.
  final List<Map<String, dynamic>> _history = [];

  bool get hasMessages => transcript.isNotEmpty;

  // Real usage from Gemini's own usageMetadata, not an estimate.
  int promptTokens = 0;
  int outputTokens = 0;

  /// Today's persisted spend. Survives app restarts, unlike the session
  /// counters above — otherwise the daily ceiling would reset on force-quit.
  CopilotUsage? _usage;
  CopilotUsage? get todayUsage => _usage;

  // ponytail: gemini-3.6-flash promotional pricing per million tokens.
  // These DOUBLE on 2027-01-01 ($1.50 in / $7.50 out) — update them then, or
  // whenever the model above changes. 2.5-flash was dropped for new API keys
  // before its announced 2026-10-16 retirement, so don't trust the sunset
  // dates: a 404 naming a successor model is the real signal.
  static const _inputUsdPerMToken = 0.75;
  static const _outputUsdPerMToken = 3.75;

  static double costUsd(int prompt, int output) =>
      prompt / 1e6 * _inputUsdPerMToken +
      output / 1e6 * _outputUsdPerMToken;

  double get sessionCostUsd => costUsd(promptTokens, outputTokens);

  double get todayCostUsd {
    final u = _usage;
    return u == null ? 0 : costUsd(u.promptTokens, u.outputTokens);
  }

  /// Reads today's spend from storage (rolling over if the date changed) so
  /// the sheet can show it before any message is sent.
  Future<CopilotUsage> loadTodayUsage() async {
    final u = (await _credsRepo.loadUsage()).forToday();
    _usage = u;
    return u;
  }

  /// Clears the conversation only. The daily spend deliberately survives —
  /// otherwise the budget ceiling would be one tap of the bin icon away from
  /// being reset.
  void clear() {
    transcript.clear();
    _history.clear();
    promptTokens = 0;
    outputTokens = 0;
  }

  /// How many user-initiated turns of context to resend. The whole history
  /// goes back to Gemini on *every* request, so an untrimmed conversation
  /// costs O(n) input tokens on its nth message — quadratic over a session.
  static const _maxTurns = 8;

  /// Drops the oldest turns, cutting only at a user text message so a
  /// functionCall is never separated from its functionResponse (the API
  /// rejects that pairing outright).
  void _trimHistory() {
    final turnStarts = <int>[];
    for (var i = 0; i < _history.length; i++) {
      final entry = _history[i];
      if (entry['role'] != 'user') continue;
      final parts = entry['parts'] as List? ?? const [];
      if (parts.any((p) => p is Map && p.containsKey('text'))) {
        turnStarts.add(i);
      }
    }
    if (turnStarts.length <= _maxTurns) return;
    _history.removeRange(0, turnStarts[turnStarts.length - _maxTurns]);
  }

  Future<void> send(String text) async {
    if (!await _credsRepo.loadCopilotEnabled()) {
      throw const CopilotException('Copilot is turned off — enable it in Settings.');
    }
    final key = (await _credsRepo.loadGeminiKey())?.trim() ?? '';
    if (key.isEmpty) {
      throw const CopilotException('No Gemini API key — add one below.');
    }

    // Third gate, checked before any HTTP so an exhausted budget costs
    // nothing. Together with the 4-hop limit this bounds what a stuck model
    // can spend in a day.
    final cap = await _credsRepo.loadDailyCapUsd();
    final usage = (_usage ?? await _credsRepo.loadUsage()).forToday();
    _usage = usage;
    if (costUsd(usage.promptTokens, usage.outputTokens) >= cap) {
      throw CopilotException(
        'Daily AI budget of \$${cap.toStringAsFixed(2)} reached. Raise it in '
        'Settings, or wait for midnight.',
      );
    }

    // A refusal is good for exactly one turn: if the user answers anything
    // other than "yes" the model simply won't call it again, and the arming
    // lapses instead of sitting armed for the rest of the session.
    _armedConfirm = _pendingConfirm;
    _pendingConfirm = null;

    transcript.add(CopilotMessage('user', text));

    // Trim before marking, so the rollback index below stays valid.
    _trimHistory();

    // On failure, drop this turn from the API history so the conversation
    // stays consistent for the next attempt (the UI shows the error).
    final mark = _history.length;
    _history.add({
      'role': 'user',
      'parts': [
        {'text': text},
      ],
    });

    try {
      // ponytail: 4 round-trips max stops a model stuck re-calling tools
      for (var hop = 0; hop < 4; hop++) {
        final content = await _generate(key);
        _history.add(content);

        final calls = functionCalls(content);
        if (calls.isEmpty) {
          final answer = textOf(content);
          transcript
              .add(CopilotMessage('model', answer.isEmpty ? 'Done.' : answer));
          return;
        }

        final responses = <Map<String, dynamic>>[];
        for (final call in calls) {
          responses.add({
            'functionResponse': {
              'name': call.name,
              'response': {'result': await _dispatch(call.name, call.args)},
            },
          });
        }
        _history.add({'role': 'user', 'parts': responses});
      }
      transcript.add(
          const CopilotMessage('model', 'Stopped after too many tool calls.'));
    } catch (_) {
      _history.removeRange(mark, _history.length);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _generate(String key) async {
    http.Response resp;
    try {
      resp = await _http
          .post(
            Uri.parse(_url),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': key,
            },
            body: jsonEncode({
              'system_instruction': {
                'parts': [
                  {'text': await _context()},
                ],
              },
              'contents': _history,
              'tools': [
                {'function_declarations': _tools},
              ],
              'generationConfig': {
                // The system prompt asks for one or two sentences; this is the
                // hard stop if the model ignores that.
                'maxOutputTokens': 512,
                // Gemini 3 thinks by default (level 'medium') and bills those
                // tokens at the output rate. Rig commands are lookups and tool
                // calls, not reasoning problems — this was the single largest
                // avoidable cost in the whole request. thinkingLevel replaces
                // 2.5's thinkingBudget; never send both.
                'thinkingConfig': {'thinkingLevel': 'minimal'},
              },
            }),
          )
          .timeout(LGDefaults.commandTimeout);
    } catch (e) {
      throw CopilotException('Could not reach Gemini: $e');
    }
    if (resp.statusCode != 200) {
      throw CopilotException(_apiError(resp));
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;

    final usage = body['usageMetadata'] as Map?;
    if (usage != null) {
      final p = (usage['promptTokenCount'] as num?)?.toInt() ?? 0;
      // thoughtsTokenCount is billed as output but reported separately, so
      // leaving it out would under-report spend against the daily cap.
      final o = ((usage['candidatesTokenCount'] as num?)?.toInt() ?? 0) +
          ((usage['thoughtsTokenCount'] as num?)?.toInt() ?? 0);
      promptTokens += p;
      outputTokens += o;

      // Persisted per hop, not per message: a turn that dies halfway through
      // its tool calls still spent those tokens.
      final next = (_usage ?? CopilotUsage.empty())
          .forToday()
          .plus(prompt: p, output: o);
      _usage = next;
      await _credsRepo.saveUsage(next);
    }

    final candidates = body['candidates'] as List? ?? const [];
    final content = candidates.isEmpty ? null : candidates.first['content'];
    if (content is! Map) {
      throw const CopilotException('Gemini returned no answer.');
    }
    return content.cast<String, dynamic>();
  }

  String _apiError(http.Response resp) {
    try {
      final msg = (jsonDecode(resp.body) as Map)['error']['message'];
      return 'Gemini error ${resp.statusCode}: $msg';
    } catch (_) {
      return 'Gemini error ${resp.statusCode}';
    }
  }

  /// Context snapshot rebuilt every request — connection state and camera
  /// target change between turns.
  ({double lat, double lng, double? range})? _cachedTarget;
  DateTime? _cachedTargetAt;

  /// The camera read is a full SSH round-trip and ran before *every* message,
  /// including each tool hop. Ten seconds is shorter than anyone can type a
  /// follow-up, and a tool call that moves the camera is already reflected in
  /// the model's own transcript.
  Future<({double lat, double lng, double? range})?> _cameraTarget() async {
    final now = DateTime.now();
    final at = _cachedTargetAt;
    if (at != null && now.difference(at) < const Duration(seconds: 10)) {
      return _cachedTarget;
    }
    _cachedTarget = await _orbit.currentTarget();
    _cachedTargetAt = now;
    return _cachedTarget;
  }

  Future<String> _context() async {
    var rig = 'NOT connected — rig actions will fail, tell the user to '
        'connect from the dashboard first.';
    var camera = 'unknown';
    if (_commands.isConnected) {
      rig = 'connected to ${_commands.host} '
          '(${_commands.nodeCount} screens).';
      final t = await _cameraTarget();
      if (t != null) {
        camera = 'lat ${t.lat}, lng ${t.lng}'
            '${t.range != null ? ', range ${t.range} m' : ''}';
      }
    }
    return 'You are QuickRig Copilot inside LG QuickRig, an app that controls '
        'a Liquid Galaxy rig (a multi-screen Google Earth wall) over SSH. '
        'Rig: $rig Current camera target: $camera. '
        'Use the tools for rig actions. You know the coordinates of world '
        'places — resolve place names to lat/lng yourself and never ask the '
        'user for coordinates. If asked to diagnose a connection error, name '
        'the likely cause and one concrete fix, in plain language a '
        'non-technical rig operator can follow. Answer in one or two short '
        'sentences unless a diagnosis needs more.';
  }

  /// Concatenated text parts of a Gemini content object.
  static String textOf(Map<String, dynamic> content) =>
      _parts(content).map((p) => p['text'] ?? '').join().trim();

  /// Every functionCall part of a Gemini content object.
  static List<({String name, Map<String, dynamic> args})> functionCalls(
      Map<String, dynamic> content) {
    return [
      for (final p in _parts(content))
        if (p['functionCall'] is Map)
          (
            name: p['functionCall']['name'] as String? ?? '',
            args: (p['functionCall']['args'] as Map?)?.cast<String, dynamic>() ??
                {},
          ),
    ];
  }

  static Iterable<Map<String, dynamic>> _parts(Map<String, dynamic> content) =>
      (content['parts'] as List? ?? const [])
          .whereType<Map>()
          .map((p) => p.cast<String, dynamic>());

  // KML colours are aabbggrr.
  static const _kmlColors = {
    'red': 'ff0000ff',
    'green': 'ff00ff00',
    'blue': 'ffff0000',
    'yellow': 'ff00ffff',
    'white': 'ffffffff',
  };

  // Reboot/shutdown/relaunch stay out of the model's reach on purpose —
  // a misheard "restart the orbit" must never power-cycle the rig.
  static const _tools = [
    {
      'name': 'fly_to',
      'description': 'Fly the rig camera to a location.',
      'parameters': {
        'type': 'object',
        'properties': {
          'lat': {'type': 'number'},
          'lng': {'type': 'number'},
          'range': {
            'type': 'number',
            'description': 'Camera distance in metres: ~1000 for a building, '
                '~10000 for a city (default), ~2000000 for a continent.',
          },
        },
        'required': ['lat', 'lng'],
      },
    },
    {
      'name': 'orbit_start',
      'description': 'Circle the camera around a point. Keeps orbiting until '
          'orbit_stop is called.',
      'parameters': {
        'type': 'object',
        'properties': {
          'lat': {'type': 'number'},
          'lng': {'type': 'number'},
          'range': {
            'type': 'number',
            'description': 'Camera distance in metres.',
          },
        },
        'required': ['lat', 'lng'],
      },
    },
    {
      'name': 'orbit_stop',
      'description': 'Stop the running orbit.',
    },
    {
      'name': 'drop_pin',
      'description': 'Drop a coloured placemark pin at a location, with an '
          'info balloon the rig operator can click to read.',
      'parameters': {
        'type': 'object',
        'properties': {
          'lat': {'type': 'number'},
          'lng': {'type': 'number'},
          'name': {'type': 'string', 'description': 'Label shown on the pin.'},
          'description': {
            'type': 'string',
            'description': '2-4 sentences of real history or notable facts '
                'about the place, shown in the pin\'s info balloon on the '
                'rig. Omit only for a spot with nothing notable.',
          },
          'color': {
            'type': 'string',
            'enum': ['red', 'green', 'blue', 'yellow', 'white'],
          },
        },
        'required': ['lat', 'lng'],
      },
    },
    {
      'name': 'clean_kml',
      'description': 'Remove every pin and overlay this app put on the rig.',
    },
    {
      'name': 'kml_test',
      'description': 'Send a test pin and fly to it, to prove KML delivery '
          'and the camera are both working.',
    },
    {
      'name': 'sync',
      'description': 'Re-sync the slave screens with the master.',
    },
    {
      'name': 'relaunch',
      'description': 'Relaunch Google Earth on every node by restarting the '
          'display manager. Earth reopens; the rig stays powered.',
    },
    {
      'name': 'reboot',
      'description': 'Reboot every node of the rig. Takes the wall down for '
          'a few minutes.',
    },
    {
      'name': 'shutdown',
      'description': 'Power off every node of the rig. Someone has to switch '
          'it back on physically.',
    },
  ];

  /// Actions that take the wall down and cannot be undone from this app. The
  /// Quick Actions grid puts them behind a confirm dialog; Copilot has no
  /// dialog, so the first call always refuses and asks. Only a call in the
  /// turn immediately after that refusal goes through.
  static const _destructive = {'reboot', 'shutdown'};

  /// Set when a destructive call was refused; consumed by the next [send].
  String? _pendingConfirm;
  String? _armedConfirm;

  Future<String> _dispatch(String name, Map<String, dynamic> args) async {
    double? d(String k) => (args[k] as num?)?.toDouble();
    try {
      // The model resolves place names to coordinates itself, so a
      // hallucinated or transposed pair reaches the rig unless it is checked
      // here. Returned as a tool failure, not thrown, so the model can say
      // what went wrong instead of the turn dying.
      if (name == 'fly_to' || name == 'drop_pin' || name == 'orbit_start') {
        final invalid = validateLatLng(d('lat'), d('lng'));
        if (invalid != null) return 'failed: $invalid';
      }

      if (_destructive.contains(name) && _armedConfirm != name) {
        _pendingConfirm = name;
        return 'confirmation required: this takes the rig down. Ask the user '
            'to confirm they want to $name, then call this again.';
      }

      switch (name) {
        case 'fly_to':
          await _orbit.flyTo(
            lat: d('lat')!,
            lng: d('lng')!,
            range: d('range') ?? 10000,
          );
          return 'ok';
        case 'orbit_start':
          final started = await _orbit.orbitPlay(
            lat: d('lat')!,
            lng: d('lng')!,
            range: d('range'),
          );
          return started
              ? 'ok — orbiting until orbit_stop'
              : 'not started: an orbit is already playing';
        case 'orbit_stop':
          await _orbit.orbitStop();
          return 'ok';
        case 'drop_pin':
          await _kml.dropPin(
            lat: d('lat')!,
            lng: d('lng')!,
            name: args['name'] as String? ?? 'Copilot Pin',
            description: args['description'] as String?,
            kmlColor: _kmlColors[args['color']] ?? 'ff0000ff',
          );
          return 'ok';
        case 'clean_kml':
          await _kml.cleanKML();
          return 'ok';
        case 'kml_test':
          await kmlSanityCheck(_kml, _orbit);
          return 'ok';
        case 'sync':
          await _commands.sync();
          return 'ok';
        case 'relaunch':
          await _commands.relaunch();
          return 'ok';
        case 'reboot':
          await _commands.reboot();
          return 'ok — rebooting';
        case 'shutdown':
          await _commands.shutdown();
          return 'ok — powering off';
      }
      return 'unknown function: $name';
    } catch (e) {
      // The model sees the failure and can explain it to the user.
      return 'failed: $e';
    }
  }
}
