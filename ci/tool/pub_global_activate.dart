import 'package:process_run/shell.dart';

Future<void> main() async {
  /// Run step
  await run('dart pub global run tekartik_ci:setup_sqlite3lib');
}
