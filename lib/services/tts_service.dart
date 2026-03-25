import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { stopped, playing, paused }

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  TtsState state = TtsState.stopped;
  String? currentText;

  Function(TtsState)? onStateChange;

  Future<void> init() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Pick a natural-sounding voice if available
    final voices = await _tts.getVoices;
    if (voices != null) {
      final preferred = (voices as List).firstWhere(
        (v) => v['name'].toString().toLowerCase().contains('samantha') ||
               v['name'].toString().toLowerCase().contains('karen') ||
               v['name'].toString().toLowerCase().contains('daniel'),
        orElse: () => null,
      );
      if (preferred != null) {
        await _tts.setVoice({'name': preferred['name'], 'locale': preferred['locale']});
      }
    }

    _tts.setStartHandler(() {
      state = TtsState.playing;
      onStateChange?.call(state);
    });

    _tts.setCompletionHandler(() {
      state = TtsState.stopped;
      currentText = null;
      onStateChange?.call(state);
    });

    _tts.setPauseHandler(() {
      state = TtsState.paused;
      onStateChange?.call(state);
    });

    _tts.setContinueHandler(() {
      state = TtsState.playing;
      onStateChange?.call(state);
    });

    _tts.setErrorHandler((msg) {
      state = TtsState.stopped;
      onStateChange?.call(state);
    });
  }

  Future<void> speak(String text) async {
    if (state == TtsState.playing) await stop();
    currentText = text;
    await _tts.speak(text);
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  Future<void> resume() async {
    await _tts.speak(currentText ?? '');
  }

  Future<void> stop() async {
    await _tts.stop();
    state = TtsState.stopped;
    currentText = null;
    onStateChange?.call(state);
  }

  bool get isPlaying => state == TtsState.playing;
  bool get isPaused => state == TtsState.paused;
}
