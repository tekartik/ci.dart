import 'package:process_run/shell_run.dart';
import 'package:tekartik_ci_support/ci_support.dart';
import 'package:test/test.dart';

void main() {
  test('dartTest', () async {
    await dartTest(Shell(workingDirectory: '../ci'));
  });
}
