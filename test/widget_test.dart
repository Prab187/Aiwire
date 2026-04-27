import 'package:flutter_test/flutter_test.dart';
import 'package:aiwire/services/claude_cache.dart';

void main() {
  group('ClaudeCache key generation', () {
    test('keyFrom produces deterministic hash', () {
      final a = ClaudeCache.keyFrom(['hello', 'world']);
      final b = ClaudeCache.keyFrom(['hello', 'world']);
      expect(a, equals(b));
    });

    test('keyFrom produces different hashes for different inputs', () {
      final a = ClaudeCache.keyFrom(['hello', 'world']);
      final b = ClaudeCache.keyFrom(['world', 'hello']);
      expect(a, isNot(equals(b)));
    });
  });
}
