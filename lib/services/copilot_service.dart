import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
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
      'models/gemini-2.5-flash:generateContent';

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

  // ponytail: gemini-2.5-flash pricing as of Aug 2026 ($0.30 in / $2.50 out
  // per million tokens) — update these when the model changes (2.5-flash
  // retires 2026-10-16) or Google repriced it.
  static const _inputUsdPerMToken = 0.30;
  static const _outputUsdPerMToken = 2.50;

  double get sessionCostUsd =>
      promptTokens / 1e6 * _inputUsdPerMToken +
      outputTokens / 1e6 * _outputUsdPerMToken;

  void clear() {
    transcript.clear();
    _history.clear();
    promptTokens = 0;
    outputTokens = 0;
  }

  Future<void> send(String text) async {
    if (!await _credsRepo.loadCopilotEnabled()) {
      throw const CopilotException('Copilot is turned off — enable it in Settings.');
    }
    final key = (await _credsRepo.loadGeminiKey())?.trim() ?? '';
    if (key.isEmpty) {
      throw const CopilotException('No Gemini API key — add one below.');
    }

    transcript.add(CopilotMessage('user', text));

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
      final o = (usage['candidatesTokenCount'] as num?)?.toInt() ?? 0;
      promptTokens += p;
      outputTokens += o;
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
  Future<String> _context() async {
    var rig = 'NOT connected — rig actions will fail, tell the user to '
        'connect from the dashboard first.';
    var camera = 'unknown';
    if (_commands.isConnected) {
      rig = 'connected to ${_commands.host} '
          '(${_commands.nodeCount} screens).';
      final t = await _orbit.currentTarget();
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
      'description': 'Slowly circle the camera 360 degrees around a point. '
          'Omit lat/lng to orbit the current view.',
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
  ];

  Future<String> _dispatch(String name, Map<String, dynamic> args) async {
    double? d(String k) => (args[k] as num?)?.toDouble();
    try {
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
            lat: d('lat'),
            lng: d('lng'),
            range: d('range'),
          );
          return started
              ? 'ok — orbiting'
              : 'not started: an orbit is already playing or no camera '
                  'target is known';
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
      }
      return 'unknown function: $name';
    } catch (e) {
      // The model sees the failure and can explain it to the user.
      return 'failed: $e';
    }
  }
}
