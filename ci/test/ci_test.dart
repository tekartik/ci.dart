import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:tekartik_ci/ci_flutter.dart';
import 'package:test/test.dart';

var top = join('.dart_tool', 'tekartik_ci');
void main() {
  group('flutter', () {
    setUp(() {});

    test('flutter test', () async {
      var dirName = join(top, 'tekartik_simple_app');
      //await generate(dirName: dirName, force: true);
      var shell = Shell(workingDirectory: dirName);
      await flutterTest(shell);
    });
  });
}
