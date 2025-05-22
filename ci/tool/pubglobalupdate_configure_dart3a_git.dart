import 'package:process_run/shell.dart';

/// To run after push.
Future<void> main() async {
  await run(
    'dart pub global run pubglobalupdate --config-package tekartik_ci --source git --git-url https://github.com/tekartik/ci.dart --git-path ci --git-ref dart3a',
  );
}
