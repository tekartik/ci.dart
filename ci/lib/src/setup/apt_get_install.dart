import 'package:process_run/shell.dart';
import 'package:process_run/stdio.dart';

/// A Debian package name, optionally with its architecture (`libfoo:i386`):
/// no apt option, no shell syntax.
final _packageNameRegExp = RegExp(r'^[a-z0-9][a-z0-9.+-]*(:[a-z0-9]+)?$');

/// apt-get as root, non interactive, waiting for the dpkg lock (unattended
/// upgrades on a fresh runner) and retrying the downloads instead of failing.
const _sudoAptGet =
    'sudo DEBIAN_FRONTEND=noninteractive apt-get'
    ' -o DPkg::Lock::Timeout=300 -o Acquire::Retries=3';

/// Install the Debian [packages] with apt-get, linux only (no-op elsewhere).
///
/// Meant for a CI runner (ubuntu, password-less sudo). The packages already
/// installed are skipped and nothing runs when none is missing, so a
/// developer machine already set up is never asked for sudo.
///
/// Throws an [ArgumentError] on an invalid package name, on every platform.
Future<void> sudoAptGetInstall(List<String> packages) async {
  for (var package in packages) {
    if (!_packageNameRegExp.hasMatch(package)) {
      throw ArgumentError.value(package, 'packages', 'invalid package name');
    }
  }
  if (!Platform.isLinux || packages.isEmpty) {
    return;
  }
  var missing = <String>[];
  for (var package in packages) {
    if (!await _isInstalled(package)) {
      missing.add(package);
    }
  }
  if (missing.isEmpty) {
    stdout.writeln('Already installed: ${packages.join(' ')}');
    return;
  }
  await run('$_sudoAptGet update');
  await run(
    '$_sudoAptGet install -y --no-install-recommends ${missing.join(' ')}',
  );
}

/// True when dpkg knows [package] as installed, false when it does not or
/// when there is no dpkg (not a Debian based linux, apt-get then fails).
Future<bool> _isInstalled(String package) async {
  try {
    var result = await Shell(
      stdin: const Stream<List<int>>.empty(),
      verbose: false,
      throwOnError: false,
    ).runExecutableArguments('dpkg-query', ['-W', r'-f=${Status}', package]);
    return result.exitCode == 0 &&
        (result.stdout as String).contains('install ok installed');
  } catch (_) {
    return false;
  }
}
