/// Stub implementation for non-web platforms.
void stopCameraHardwareImpl() {
  // MobileScannerController already releases the hardware camera on Android/iOS/desktop
  // when stop() and dispose() are called.
}
