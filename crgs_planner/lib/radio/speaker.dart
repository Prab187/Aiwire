import 'package:flutter_tts/flutter_tts.dart';

/// Reads text aloud. A small wrapper so the radio can be tested without a phone.
abstract class Speaker {
  /// Speaks [text]. Completes when it has been read out, or when [stop] is called.
  Future<void> speak(String text);
  Future<void> stop();

  /// 1.0 is normal speed.
  Future<void> setRate(double multiplier);
}

/// Uses the iPhone's built-in text-to-speech voice. Works offline.
class TtsSpeaker implements Speaker {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.setLanguage('en-GB');
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Keep going with the default voice settings.
    }
  }

  @override
  Future<void> speak(String text) async {
    await _init();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<void> setRate(double multiplier) async {
    await _init();
    // iPhone speech rate: 0.5 is normal.
    await _tts.setSpeechRate((0.5 * multiplier).clamp(0.2, 0.9));
  }
}
