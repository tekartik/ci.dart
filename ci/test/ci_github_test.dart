import 'package:tekartik_ci/ci_github.dart';
import 'package:test/test.dart';

Future<void> main() async {
  test('gi', () async {
    // ignore: avoid_print
    print('runningInGithubActions: $runningInGithubActions');
    // Just a placeholder to have a test file
  });
}
