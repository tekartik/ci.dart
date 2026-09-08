import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';

/// Setup alsa lib (libasound2), only needed for linux, to run with sudo
Future<void> sudoSetupAlsaLib() async {
  /// Add extra tools to build on linux
  ///
  /// Can only be called from CI without any sudo access issue.
  if (Platform.isLinux) {
    // Assuming ubuntu, to run as sudo
    await run('sudo apt-get update');
    await run('sudo apt-get -y install libasound2-dev');
  }
}
