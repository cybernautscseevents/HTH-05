import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

@JS('window')
external JSObject get _window;

bool startWebSpeech(
  void Function(String words, bool isFinal) onResult,
  void Function(String status) onStatus,
  void Function(String error) onError,
) {
  try {
    final startFn = _window.getProperty('saathiStartSpeech'.toJS);
    if (startFn.isUndefined) return false;

    final onResultJs = ((JSString text, JSBoolean isFinal) {
      onResult(text.toDart, isFinal.toDart);
    }).toJS;

    final onStatusJs = ((JSString status) {
      onStatus(status.toDart);
    }).toJS;

    final onErrorJs = ((JSString error) {
      onError(error.toDart);
    }).toJS;

    final result = _window.callMethod(
      'saathiStartSpeech'.toJS,
      onResultJs,
      onStatusJs,
      onErrorJs,
    );
    return (result as JSBoolean?)?.toDart ?? true;
  } catch (e) {
    debugPrint('Web speech error: $e');
    return false;
  }
}

void stopWebSpeech() {
  try {
    _window.callMethod('saathiStopSpeech'.toJS);
  } catch (_) {}
}
