# tekartik_ci

Setup tools for CI runners: install the Linux native libraries a GitHub
Actions ubuntu runner lacks (sqlite3, portaudio, alsa, gtk3) and tell whether
a program runs in GitHub Actions. The CI workflows themselves (reusable
workflows and actions) are documented in the
[repository README](../README.md).

## Getting started

On a runner, activate the package from git and run a setup executable before
the tests:

```yaml
jobs:
  build:
    steps:
      - name: Install libsqlite3
        run: |
          dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
          dart pub global run tekartik_ci:setup_sqlite3lib
```

With the reusable flutter workflows of this repository, pass the executables
to run instead: `tekartik-ci-setup: setup_gtk3lib` (space separated).

| Executable | Debian packages | Fixes |
|---|---|---|
| `setup_sqlite3lib` | `libsqlite3-dev` | `Failed to load dynamic library 'libsqlite3.so'` |
| `setup_portaudiolib` | `portaudio19-dev` | `Failed to load dynamic library 'libportaudio.so'` |
| `setup_alsalib` | `libasound2-dev` | `Failed to load dynamic library 'libasound.so'` ([flutter_soloud](https://docs.page/alnitak/flutter_soloud_docs/get_started/setup#linux-setup), [flutter_sound](https://pub.dev/packages/flutter_sound#linux-setup)) |
| `setup_gtk3lib` | `libgtk-3-dev libx11-dev libxi-dev` | `pkg-config --cflags gtk+-3.0 x11 xi` failing in the native build hook that `flutter test` runs for `window_manager` >= 0.6.0 |

Every executable is a no-op off Linux (macOS and Windows runners). It runs
`sudo apt-get`: an ubuntu runner (password-less sudo) only, never a developer
script.

## Dart API

Not on pub.dev, as a git dependency (the package is in the `ci` folder):

```yaml
dev_dependencies:
  tekartik_ci:
    git:
      url: https://github.com/tekartik/ci.dart
      path: ci
```

```dart
import 'package:tekartik_ci/ci_github.dart';
import 'package:tekartik_ci/setup_ci_github.dart';

Future<void> main() async {
  if (!runningInGithubActions) {
    print('not on GitHub Actions, nothing to install');
    return;
  }
  // Skips the packages already installed, waits for the dpkg lock and
  // retries the downloads.
  await sudoAptGetInstall(['libsqlite3-dev', 'libgtk-3-dev']);
}
```

* `package:tekartik_ci/setup_ci_github.dart`: `sudoAptGetInstall(packages)`
  (rejects anything but a package name, no sudo when nothing is missing),
  `sudoSetupSqlite3Lib()`, `sudoSetupPortaudioLib()`, `sudoSetupAlsaLib()`,
  `sudoSetupGtk3Lib()`.
* `package:tekartik_ci/ci_github.dart`: `runningInGithubActions`
  (`GITHUB_ACTIONS == 'true'`), `dart:io` only.
* `package:tekartik_ci/ci.dart` is an empty placeholder and
  `ci_flutter.dart` holds deprecated helpers: do not use them.

## Common pitfalls

* A failing `apt-get` throws: the executable exits with a non zero code and
  the job fails, as it should.
* Only `sudoAptGetInstall` and `sudoSetupGtk3Lib` wait for the dpkg lock and
  skip installed packages; the three older setups run a plain
  `sudo apt-get update` and `install`.
* Debian based Linux only (`apt-get`, `dpkg-query`).

Agent skill: [skills/tekartik-ci-setup](skills/tekartik-ci-setup/SKILL.md).
