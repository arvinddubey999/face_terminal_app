import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      print("TTS Init Error: $e");
    }
  }

  static Future<void> speak(String text) async {
    await init();
    try {
      await _tts.speak(text);
    } catch (e) {
      print("TTS Speak Error: $e");
    }
  }
}
