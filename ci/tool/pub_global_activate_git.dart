import 'package:process_run/shell.dart';

Future<void> main() async {
  await run(
      'dart pub global activate --source git git@github.com:tekartikprv/tools.dart.git --git-path ci --git-ref dart3a');
}
