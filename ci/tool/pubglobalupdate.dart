import 'package:process_run/shell.dart';

/// To run after push.
Future<void> main() async {
  await run('dart pub global run pubglobalupdate tekartik_ci');
}
