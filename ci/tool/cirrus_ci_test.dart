import 'package:process_run/shell.dart';

Future main() async {
  var shell = Shell();

  await shell.run('''
flutter format --set-exit-if-changed .
flutter analyze --no-current-package --fatal-warnings --fatal-infos .
flutter test
''');
}
