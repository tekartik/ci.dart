---
name: tekartik-ci-setup
description: >-
  Use when setting up continuous integration for a tekartik Dart or Flutter
  repository with tekartik_ci: installing the native libraries a CI runner is
  missing (sudoSetupSqlite3Lib, sudoSetupPortaudioLib, sudoSetupAlsaLib from
  package:tekartik_ci/setup_ci_github.dart, or the setup_sqlite3lib /
  setup_portaudiolib / setup_alsalib executables run through
  `dart pub global activate --source git ... --git-path ci`), detecting the
  runner with runningInGithubActions from ci_github.dart, and wiring the
  reusable tekartik/ci.dart GitHub actions (run_ci_dart, run_ci_flutter,
  run_ci_flutter_analyze) that run dev_build:run_ci --recursive.
---

# CI helpers for Dart and Flutter repos (tekartik_ci)

`tekartik_ci` is the tiny Dart side of the `ci.dart` repo: three executables
that `apt-get install` the Linux native libraries CI runners lack, and one
flag telling you whether the process runs inside GitHub Actions. The bigger
half of the repo is the set of reusable composite GitHub actions under
`tekartik/ci.dart/.github/actions/`, which this skill also covers.

## Guidelines

* Dependency (git, not on pub.dev; the package sits in the `ci` folder of the
  repo, so `path:` is required):
  ```yaml
  dev_dependencies:
    tekartik_ci:
      git:
        url: https://github.com/tekartik/ci.dart
        path: ci
  ```
  On CI you usually do not depend on it at all — activate it globally
  instead, which needs no checkout and no pubspec change:
  ```bash
  dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
  dart pub global run tekartik_ci:setup_sqlite3lib
  ```
* Public entry points (there are only four):
  - `package:tekartik_ci/setup_ci_github.dart` — `sudoSetupSqlite3Lib()`,
    `sudoSetupPortaudioLib()`, `sudoSetupAlsaLib()`.
  - `package:tekartik_ci/ci_github.dart` — `bool get runningInGithubActions`.
  - `package:tekartik_ci/ci.dart` — empty placeholder, nothing to import.
  - `package:tekartik_ci/ci_flutter.dart` — `setup()`, `generate()`,
    `flutterTest()`, all `@Deprecated('To remove')`. Do not use them in new
    code; drive Flutter from `package:process_run` directly.
* The three `sudoSetup*Lib()` functions are **no-ops off Linux** (they check
  `Platform.isLinux`) and run `sudo apt-get update` plus
  `sudo apt-get -y install <dev package>` through `package:process_run`'s
  `run`. They assume an Ubuntu runner with password-less sudo, so call them
  from CI only, never from an application or a developer machine script.
  Mapping: `libsqlite3-dev` (fixes `Failed to load dynamic library
  'libsqlite3.so'`, i.e. `sqlite3`/`sqflite_common_ffi`), `portaudio19-dev`
  (`libportaudio.so`), `libasound2-dev` (`libasound.so`, needed by
  `flutter_soloud` and `flutter_sound`).
* Matching executables declared in `pubspec.yaml`: `setup_sqlite3lib`,
  `setup_portaudiolib`, `setup_alsalib`. Each `bin/*.dart` is a two-line
  `main` awaiting the corresponding function — copy that shape for a new
  library.
* `runningInGithubActions` is `Platform.environment['GITHUB_ACTIONS'] ==
  'true'` (via `tekartik_platform_io`'s `platformIo.runningOnGithub`). Use it
  to skip tests that need a real display, network or sudo, or to only install
  system packages on the runner. It is `dart:io` based: do not import
  `ci_github.dart` from web or Flutter-web code.
* Reusable GitHub actions, referenced by the moving `@v1` tag (add the
  workflow at `.github/workflows/run_ci.yml`):
  - `tekartik/ci.dart/.github/actions/run_ci_dart@v1` — checkout, set up the
    Dart SDK, `dart pub global activate dev_build`, then
    `dart pub global run dev_build:run_ci --recursive`.
  - `.../run_ci_flutter@v1` — same for Flutter.
  - `.../run_ci_flutter_analyze@v1` — `pub downgrade` + analyze, then
    `pub upgrade` + analyze, to check both ends of the constraints.
  - `.../setup_ci_dart@v1`, `.../setup_ci_flutter@v1`,
    `.../run_ci_no_setup@v1`, `.../setup_ci_dart_latest@v1`,
    `.../run_ci_dart_latest@v1` for finer-grained pipelines.
  Inputs (all optional but `dart-channel` / `flutter-channel`, default
  `stable`): `cache` (`true`), `cache-key-prefix` (`flutter`),
  `working-directory` (`.`), `checkout-token` (`${{ github.token }}`, set it
  for private repos).
* `dev_build:run_ci` is what actually runs the checks in each package
  (format check, analyze, test); `--recursive` walks every package of a
  mono-repo. Keep per-package tweaks in the package, not in the workflow.
* Anti-pattern: pinning a workflow to `@master`. The actions are consumed
  through `@v1`, which repo maintainers move on release
  (`repo_support/tool/new_tag_current_and_v1_and_push.dart`); a change pushed
  to `master` does not reach consumers until `v1` moves.

## Examples

### CI entry point installing a native library (bin/setup_sqlite3lib.dart)

```dart
import 'package:tekartik_ci/setup_ci_github.dart';

Future<void> main() async {
  /// Linux only, no op on other platforms
  await sudoSetupSqlite3Lib();
}
```

### One tool installing everything a runner needs

```dart
import 'package:tekartik_ci/ci_github.dart';
import 'package:tekartik_ci/setup_ci_github.dart';

/// tool/setup_ci.dart: run from the workflow before the tests.
Future<void> main() async {
  if (!runningInGithubActions) {
    print('not on github actions, skipping sudo apt-get install');
    return;
  }
  await sudoSetupSqlite3Lib(); // libsqlite3-dev
  await sudoSetupPortaudioLib(); // portaudio19-dev
  await sudoSetupAlsaLib(); // libasound2-dev
}
```

### Skipping a test that only makes sense on the runner

```dart
import 'package:tekartik_ci/ci_github.dart';
import 'package:test/test.dart';

void main() {
  test('needs the CI native libraries', () {
    // ...
  }, skip: runningInGithubActions ? null : 'github actions only');

  test('local only', () {
    // ...
  }, skip: runningInGithubActions ? 'not on the runner' : null);
}
```

### Workflow: dart matrix CI

```yaml
# .github/workflows/run_ci.yml
name: Run CI dart
on:
  push:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'

jobs:
  test:
    name: Test on ${{ matrix.os }} / dart ${{ matrix.dart }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: ubuntu-latest
            dart: stable
          - os: ubuntu-latest
            dart: beta
          - os: windows-latest
            dart: stable
          - os: macos-latest
            dart: stable
    steps:
      - name: Install libsqlite3
        if: runner.os == 'Linux'
        run: |
          dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
          dart pub global run tekartik_ci:setup_sqlite3lib
      - name: Run CI dart
        uses: tekartik/ci.dart/.github/actions/run_ci_dart@v1
        with:
          dart-channel: ${{ matrix.dart }}
```

### Workflow: flutter CI plus downgrade/upgrade analysis

```yaml
# .github/workflows/run_ci_flutter.yml
name: Run CI flutter
on: [push, workflow_dispatch]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Install libasound2 (flutter_soloud / flutter_sound)
        run: |
          dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
          dart pub global run tekartik_ci:setup_alsalib
      - name: Run CI flutter
        uses: tekartik/ci.dart/.github/actions/run_ci_flutter@v1
        with:
          flutter-channel: stable
  analysis:
    runs-on: ubuntu-latest
    steps:
      - name: Full flutter analysis (downgrade then upgrade)
        uses: tekartik/ci.dart/.github/actions/run_ci_flutter_analyze@v1
        with:
          flutter-channel: stable
```

## Common mistakes

* Calling `sudoSetup*Lib()` from application code or a developer script: it
  shells out to `sudo apt-get` and only makes sense on a CI runner.
* Expecting it to work on a non-Debian Linux image: the commands are
  `apt-get`, other distributions need their own step.
* Importing `package:tekartik_ci/ci.dart` expecting an API — it is an empty
  placeholder.
* Using `setup()`, `generate()` or `flutterTest()` from `ci_flutter.dart`:
  all deprecated and slated for removal.
* Referencing the actions with `@master` instead of `@v1`.
