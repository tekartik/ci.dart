import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';

/// Setup sqlite3, only needed for linux, to run with sudo
Future<void> sudoSetupSqlite3Lib() async {
  /// Add extra tools to build on linux
  ///
  /// Can only be called from CI without any sudo access issue.
  if (Platform.isLinux) {
    // Assuming ubuntu, to run as sudo
    await run('sudo apt-get -y install libsqlite3-dev');
  }
}
