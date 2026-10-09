import 'dart:js_interop';

@JS('stopAllSaathiCameras')
external void _stopAllSaathiCameras();

/// Shuts down all active camera media tracks and video element streams on web.
void stopCameraHardwareImpl() {
  try {
    _stopAllSaathiCameras();
  } catch (_) {
    // Silently ignore if invoked before DOM or window helper is ready.
  }
}
