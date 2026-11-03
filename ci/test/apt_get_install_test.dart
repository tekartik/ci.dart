import 'package:tekartik_ci/setup_ci_github.dart';
import 'package:test/test.dart';

void main() {
  group('sudoAptGetInstall', () {
    test('invalid package name', () async {
      for (var name in [
        '',
        '-y',
        '--allow-unauthenticated',
        'libfoo; rm -rf /',
        r'$(id)',
        'LibFoo',
        'lib foo',
      ]) {
        await expectLater(
          sudoAptGetInstall(['libgtk-3-dev', name]),
          throwsArgumentError,
          reason: name,
        );
      }
    });
    test('nothing to install', () async {
      await sudoAptGetInstall([]);
    });
  });
}
