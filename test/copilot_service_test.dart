import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lg_quickrig/data/repositories/credentials_repository.dart';
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

    test('a safe node action reaches the rig with no confirmation', () async {
      final copilot = copilotReplying([
        modelCalls('sync', {}),
        modelSays('Synced.'),
      ]);

      await copilot.send('sync the screens');

      expect(rig.actions, ['sync']);
    });

    // Reboot and shutdown have no confirm dialog in the chat, so the gate is
    // in the dispatcher: the first call must refuse and leave the rig alone.
    test('a destructive action is refused until the next turn confirms it',
        () async {
      // One canned reply per HTTP round-trip: call, answer, call again,
      // answer.
      final copilot = copilotReplying([
        modelCalls('reboot', {}),
        modelSays('That reboots the whole wall. Confirm?'),
        modelCalls('reboot', {}),
        modelSays('Rebooting now.'),
      ]);

      await copilot.send('reboot the rig');

      expect(rig.actions, isEmpty, reason: 'first call must not reach the rig');
      final refusal = jsonEncode(requests.last['contents']);
      expect(refusal, contains('confirmation required'));

      await copilot.send('yes, do it');

      expect(rig.actions, ['reboot']);
    });

    test('an unconfirmed destructive call does not stay armed', () async {
      final copilot = copilotReplying([
        modelCalls('shutdown', {}),
        modelSays('Confirm?'),
        modelSays('I cannot check the weather.'),
        modelCalls('shutdown', {}),
        modelSays('Confirm?'),
      ]);

      await copilot.send('shut down the rig');
      expect(rig.actions, isEmpty);

      // The user changed the subject instead of confirming, so the arming
      // lapses and a later shutdown has to ask all over again.
      await copilot.send('never mind, what is the weather');
      await copilot.send('actually shut it down');

      expect(rig.actions, isEmpty);
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
      // $0.75 per M in, $3.75 per M out.
      expect(copilot.sessionCostUsd, closeTo(200 / 1e6 * 0.75 + 40 / 1e6 * 3.75, 1e-12));
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

  // Everything that stands between a stuck model and the user's credit card.
  group('cost controls', () {
    late FakeCommandService rig;
    late FakeCredentialsRepository creds;
    late List<Map<String, dynamic>> requests;

    CopilotService copilotReplying(List<Map<String, dynamic>> replies) {
      final client = MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        final reply = replies[requests.length.clamp(1, replies.length) - 1];
        return http.Response(
          jsonEncode(reply),
          200,
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

    Map<String, dynamic> reply(String text, {int prompt = 100, int out = 20}) =>
        {
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
            'promptTokenCount': prompt,
            'candidatesTokenCount': out,
          },
        };

    setUp(() {
      rig = FakeCommandService();
      creds = FakeCredentialsRepository()
        ..copilotEnabled = true
        ..geminiKey = 'test-key';
      requests = [];
    });

    // Gemini 3 bills thinking tokens at the output rate and thinks by
    // default; the request must turn that down explicitly.
    test('every request disables thinking and caps output length', () async {
      final copilot = copilotReplying([reply('Hi.')]);

      await copilot.send('hello');

      final cfg = requests.single['generationConfig'] as Map;
      expect(cfg['maxOutputTokens'], 512);
      expect((cfg['thinkingConfig'] as Map)['thinkingLevel'], 'minimal');
    });

    test('thinking tokens count towards spend even though reported apart',
        () async {
      final copilot = copilotReplying([
        {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {'text': 'Hi.'},
                ],
              }
            }
          ],
          'usageMetadata': {
            'promptTokenCount': 100,
            'candidatesTokenCount': 20,
            'thoughtsTokenCount': 300,
          },
        }
      ]);

      await copilot.send('hello');

      expect(copilot.outputTokens, 320);
    });

    test('spend is persisted, so it survives a restart', () async {
      final first = copilotReplying([reply('Hi.')]);
      await first.send('hello');

      expect(creds.usage.promptTokens, 100);

      // A fresh service over the same storage — as after a force-quit.
      requests = [];
      final second = copilotReplying([reply('Hi again.')]);
      final restored = await second.loadTodayUsage();

      expect(restored.promptTokens, 100);
      expect(restored.outputTokens, 20);
    });

    test('usage from an earlier day does not count against today', () async {
      creds.usage = const CopilotUsage(
        day: '2020-01-01',
        promptTokens: 999999999,
        outputTokens: 999999999,
      );
      final copilot = copilotReplying([reply('Hi.')]);

      // Yesterday's overspend must not block today.
      await copilot.send('hello');

      expect(requests, hasLength(1));
      expect(copilot.todayUsage!.promptTokens, 100);
    });

    test('an exhausted daily budget blocks the send before any HTTP',
        () async {
      creds.dailyCapUsd = 0.01;
      creds.usage = CopilotUsage(
        day: CopilotUsage.today(),
        // Well past $0.01 at $3.75 per million output tokens.
        promptTokens: 0,
        outputTokens: 100000,
      );
      final copilot = copilotReplying([reply('should not happen')]);

      await expectLater(
        copilot.send('hi'),
        throwsA(predicate((e) =>
            e is CopilotException && e.message.contains('Daily AI budget'))),
      );
      expect(requests, isEmpty);
    });

    test('clearing the chat does not clear the day\'s spend', () async {
      final copilot = copilotReplying([reply('Hi.')]);
      await copilot.send('hello');

      copilot.clear();

      expect(copilot.todayUsage!.promptTokens, 100);
      expect(creds.usage.promptTokens, 100);
    });

    // The full history is resent on every request, so an untrimmed
    // conversation costs O(n) input tokens on its nth message.
    test('history is trimmed to the most recent turns', () async {
      final copilot = copilotReplying([reply('ok')]);

      for (var i = 0; i < 12; i++) {
        await copilot.send('message $i');
      }

      final contents = requests.last['contents'] as List;
      // 8 kept turns (user + model each) plus the new user message.
      expect(contents.length, lessThanOrEqualTo(18));
      expect(contents.last['parts'][0]['text'], 'message 11');
      // The oldest messages are gone.
      expect(jsonEncode(contents), isNot(contains('message 0"')));
    });

    // Splitting a functionCall from its functionResponse makes the API reject
    // the whole request, so the trim may only cut at a user text message.
    test('trimming never separates a tool call from its response', () async {
      final copilot = copilotReplying([
        {
          'candidates': [
            {
              'content': {
                'role': 'model',
                'parts': [
                  {
                    'functionCall': {'name': 'orbit_stop', 'args': {}}
                  },
                ],
              }
            }
          ],
          'usageMetadata': {
            'promptTokenCount': 10,
            'candidatesTokenCount': 5,
          },
        },
        reply('done'),
      ]);

      for (var i = 0; i < 12; i++) {
        await copilot.send('stop $i');
      }

      final contents = requests.last['contents'] as List;
      for (var i = 0; i < contents.length; i++) {
        final parts = (contents[i]['parts'] as List).cast<Map>();
        if (parts.any((p) => p.containsKey('functionResponse'))) {
          // Whatever precedes a response must be the call it answers.
          expect(i, greaterThan(0));
          final before = (contents[i - 1]['parts'] as List).cast<Map>();
          expect(before.any((p) => p.containsKey('functionCall')), isTrue);
        }
      }
    });
  });
}
