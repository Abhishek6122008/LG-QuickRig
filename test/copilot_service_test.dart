import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lg_quickrig/services/copilot_service.dart';
import 'package:lg_quickrig/services/lg_kml_controller.dart';
import 'package:lg_quickrig/services/lg_orbit_controller.dart';

import 'fakes.dart';

// Gemini response parsing — the part of the copilot that breaks silently
// if the API shape is misread.
void main() {
  group('response parsing', () {
    test('textOf joins text parts and skips non-text parts', () {
      final content = {
        'role': 'model',
        'parts': [
          {'text': 'Flying '},
          {
            'functionCall': {'name': 'fly_to', 'args': {}}
          },
          {'text': 'to Rome.'},
        ],
      };
      expect(CopilotService.textOf(content), 'Flying to Rome.');
    });

    test('functionCalls extracts every call with its args', () {
      final content = {
        'role': 'model',
        'parts': [
          {
            'functionCall': {
              'name': 'fly_to',
              'args': {'lat': 41.9, 'lng': 12.5},
            }
          },
          {
            'functionCall': {'name': 'orbit_start'}
          },
        ],
      };
      final calls = CopilotService.functionCalls(content);
      expect(calls.length, 2);
      expect(calls[0].name, 'fly_to');
      expect(calls[0].args['lat'], 41.9);
      expect(calls[1].name, 'orbit_start');
      expect(calls[1].args, isEmpty);
    });

    test('content without parts yields no calls and empty text', () {
      expect(CopilotService.functionCalls({'role': 'model'}), isEmpty);
      expect(CopilotService.textOf({'role': 'model'}), '');
    });
  });

  // The tool-calling loop, driven by canned Gemini responses. The controllers
  // underneath are real — only the SSH transport and the HTTP call are faked —
  // so these assert the command that would actually reach the rig.
  group('tool-calling loop', () {
    late FakeCommandService rig;
    late FakeCredentialsRepository creds;
    late List<Map<String, dynamic>> requests;

    /// One canned reply per HTTP round-trip, in order; the last one repeats.
    CopilotService copilotReplying(List<Map<String, dynamic>> replies) {
      final client = MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        final reply = replies[requests.length.clamp(1, replies.length) - 1];
        return http.Response(
          jsonEncode(reply),
          reply.containsKey('_status') ? reply['_status'] as int : 200,
          headers: {'content-type': 'application/json'},
        );
      });
      return CopilotService(
        rig,
        LGKMLController(rig),
        LGOrbitController(rig),
        creds,
        client: client,
      );
    }

    Map<String, dynamic> modelSays(String text) => {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': text},
                ],
              }
            }
          ],
          'usageMetadata': {
            'promptTokenCount': 100,
            'candidatesTokenCount': 20,
          },
        };

    Map<String, dynamic> modelCalls(String name, Map<String, dynamic> args) => {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {
                    'functionCall': {'name': name, 'args': args}
                  },
                ],
              }
            }
          ],
          'usageMetadata': {
            'promptTokenCount': 100,
            'candidatesTokenCount': 20,
          },
        };

    setUp(() {
      rig = FakeCommandService();
      creds = FakeCredentialsRepository()
        ..copilotEnabled = true
        ..geminiKey = 'test-key';
      requests = [];
    });

    test('a functionCall is dispatched onto the real rig controllers',
        () async {
      final copilot = copilotReplying([
        modelCalls('fly_to', {'lat': 41.9, 'lng': 12.5}),
        modelSays('Flying to Rome.'),
      ]);

      await copilot.send('fly to Rome');

      expect(rig.only('query.txt'), contains('<latitude>41.9</latitude>'));
      expect(copilot.transcript.last.role, 'model');
      expect(copilot.transcript.last.text, 'Flying to Rome.');
    });

    test('a dropped pin carries the description Gemini wrote', () async {
      final copilot = copilotReplying([
        modelCalls('drop_pin', {
          'lat': 41.9,
          'lng': 12.5,
          'name': 'Colosseum',
          'description': 'Completed in AD 80.',
          'color': 'green',
        }),
        modelSays('Pinned.'),
      ]);

      await copilot.send('pin the Colosseum');

      expect(rig.commands.first,
          contains('<description>Completed in AD 80.</description>'));
      expect(rig.commands.first, contains('<color>ff00ff00</color>'));
    });

    test('the tool result is fed back to the model', () async {
      final copilot = copilotReplying([
        modelCalls('clean_kml', {}),
        modelSays('Cleaned.'),
      ]);

      await copilot.send('clear the rig');

      // Second request must carry the functionResponse from the first.
      final parts = (requests[1]['contents'] as List).last['parts'] as List;
      expect(parts.first['functionResponse']['name'], 'clean_kml');
      expect(parts.first['functionResponse']['response']['result'], 'ok');
    });

    // A model that keeps re-calling tools would otherwise loop forever on the
    // user's own API credits.
    test('stops after 4 round-trips of nothing but tool calls', () async {
      final copilot = copilotReplying([
        modelCalls('orbit_stop', {}),
      ]);

      await copilot.send('orbit forever');

      expect(requests.length, 4);
      expect(copilot.transcript.last.text, 'Stopped after too many tool calls.');
    });

    test('token usage and cost accumulate across round-trips', () async {
      final copilot = copilotReplying([
        modelCalls('orbit_stop', {}),
        modelSays('Stopped.'),
      ]);

      await copilot.send('stop orbiting');

      expect(copilot.promptTokens, 200);
      expect(copilot.outputTokens, 40);
      // $0.30 per M in, $2.50 per M out.
      expect(copilot.sessionCostUsd, closeTo(200 / 1e6 * 0.30 + 40 / 1e6 * 2.50, 1e-12));
    });

    test('a failed turn is rolled back so the next one still works', () async {
      final copilot = copilotReplying([
        {
          '_status': 429,
          'error': {'message': 'Quota exceeded'},
        },
        modelSays('Hello.'),
      ]);

      await expectLater(
        copilot.send('first try'),
        throwsA(isA<CopilotException>()),
      );
      await copilot.send('second try');

      // The failed turn left nothing behind: the retry's history is just its
      // own user message.
      expect((requests[1]['contents'] as List).length, 1);
      expect(copilot.transcript.last.text, 'Hello.');
    });

    test('the API error message reaches the user', () async {
      final copilot = copilotReplying([
        {
          '_status': 400,
          'error': {'message': 'API key not valid'},
        },
      ]);

      expect(
        () => copilot.send('hi'),
        throwsA(predicate((e) =>
            e is CopilotException && e.message.contains('API key not valid'))),
      );
    });

    // Copilot spends the user's own credits — neither switch may be bypassed.
    test('refuses to call out when Copilot is switched off', () async {
      creds.copilotEnabled = false;
      final copilot = copilotReplying([modelSays('should not happen')]);

      await expectLater(
        copilot.send('hi'),
        throwsA(isA<CopilotException>()),
      );
      expect(requests, isEmpty);
    });

    test('refuses to call out with no API key', () async {
      creds.geminiKey = '  ';
      final copilot = copilotReplying([modelSays('should not happen')]);

      await expectLater(
        copilot.send('hi'),
        throwsA(isA<CopilotException>()),
      );
      expect(requests, isEmpty);
    });

    test('clear wipes the transcript and the cost counters', () async {
      final copilot = copilotReplying([modelSays('Hi.')]);
      await copilot.send('hello');

      copilot.clear();

      expect(copilot.hasMessages, isFalse);
      expect(copilot.promptTokens, 0);
      expect(copilot.sessionCostUsd, 0);
    });
  });
}
