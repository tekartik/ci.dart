import 'package:process_run/shell.dart';

Future<void> main() async {
  await run(
      'dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci --git-ref dart3a');
}
