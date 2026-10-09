import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'speech_web_bridge_stub.dart'
    if (dart.library.js_interop) 'speech_web_bridge.dart';

class SpeechDictationHelper {
  static final SpeechDictationHelper instance = SpeechDictationHelper._();
  SpeechDictationHelper._();

  final SpeechToText _speech = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isAvailable => kIsWeb ? true : _speech.isAvailable;

  Future<bool> initialize() async {
    if (kIsWeb) {
      _isInitialized = true;
      return true;
    }
    if (_isInitialized) return _speech.isAvailable;
    try {
      _isInitialized = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('Speech error: ${error.errorMsg}');
          _isListening = false;
        },
        onStatus: (String status) {
          debugPrint('Speech status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<bool> startListening({
    required void Function(String words, bool isFinal) onResult,
    required VoidCallback onStopped,
    required void Function(String error) onError,
  }) async {
    if (kIsWeb) {
      final started = startWebSpeech(
        (words, isFinal) {
          onResult(words, isFinal);
        },
        (status) {
          if (status == 'stopped') {
            _isListening = false;
            onStopped();
          } else if (status == 'listening') {
            _isListening = true;
          }
        },
        (err) {
          _isListening = false;
          onError(err);
        },
      );
      _isListening = started;
      return started;
    }

    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        onError('Microphone not available or permission denied.');
        return false;
      }
    }

    try {
      _isListening = true;
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
        ),
      );
      return true;
    } catch (e) {
      _isListening = false;
      onError('Failed to start voice dictation: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    if (kIsWeb) {
      stopWebSpeech();
      return;
    }
    try {
      await _speech.stop();
    } catch (_) {}
  }
}
