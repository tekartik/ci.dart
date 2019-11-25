import 'package:path/path.dart';
import 'package:process_run/shell_run.dart';

Future main() async {
  for (var dir in ['ci']) {
    var shell = Shell(workingDirectory: join('..', dir));
    await shell.run('''
    pub get
    dart tool/cirrus_ci_test.dart
    ''');
  }
}
