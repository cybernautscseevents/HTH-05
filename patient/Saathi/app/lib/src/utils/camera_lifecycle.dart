import 'camera_lifecycle_stub.dart'
    if (dart.library.js_interop) 'camera_lifecycle_web.dart';

/// Shuts down any active camera hardware tracks in the application.
///
/// On web, this calls the JavaScript hook to stop all active MediaStreamTracks
/// created by getUserMedia, ensuring the browser camera indicator and hardware
/// light turn off. On native platforms, MobileScannerController handles native
/// camera release upon stop/dispose.
void stopCameraHardware() {
  stopCameraHardwareImpl();
}
