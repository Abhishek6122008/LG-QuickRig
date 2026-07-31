import 'package:flutter_test/flutter_test.dart';
import 'package:lg_quickrig/services/copilot_service.dart';

// Gemini response parsing — the part of the copilot that breaks silently
// if the API shape is misread.
void main() {
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
}
