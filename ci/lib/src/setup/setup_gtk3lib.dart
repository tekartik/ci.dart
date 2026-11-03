import 'apt_get_install.dart';

/// Setup the GTK 3, X11 and Xi development packages, only needed for linux,
/// to run with sudo.
///
/// Needed by the native build hooks that `flutter test` runs for a package
/// depending on nativeapi (`window_manager` >= 0.6.0).
///
/// Can only be called from CI without any sudo access issue.
Future<void> sudoSetupGtk3Lib() async {
  await sudoAptGetInstall(['libgtk-3-dev', 'libx11-dev', 'libxi-dev']);
}
