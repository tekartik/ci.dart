---
name: tekartik-ci-setup
description: >-
  Use when setting up continuous integration for a tekartik Dart or Flutter
  repository with tekartik_ci: installing the native libraries a CI runner is
  missing (sudoAptGetInstall, sudoSetupSqlite3Lib, sudoSetupPortaudioLib,
  sudoSetupAlsaLib, sudoSetupGtk3Lib from
  package:tekartik_ci/setup_ci_github.dart, or the setup_sqlite3lib /
  setup_portaudiolib / setup_alsalib / setup_gtk3lib executables run through
  `dart pub global activate --source git ... --git-path ci`), detecting the
  runner with runningInGithubActions from ci_github.dart, the
  tekartik-ci-setup input of the reusable run_ci_flutter_jobs.yml, and wiring
  the tekartik/ci.dart reusable workflows (run_ci_workflow_*_all_platform.yml,
  run_ci_workflow_flutter_analyze.yml) or the older actions (run_ci_dart,
  run_ci_flutter, run_ci_flutter_analyze) that run dev_build:run_ci
  --recursive.
---

# CI helpers for Dart and Flutter repos (tekartik_ci)

`tekartik_ci` is the tiny Dart side of the `ci.dart` repo: four executables
that `apt-get install` the Linux native libraries CI runners lack, and one
flag telling you whether the process runs inside GitHub Actions. The bigger
half of the repo is the set of reusable workflows and composite actions
under `tekartik/ci.dart/.github/`, which this skill also covers.

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
    `sudoSetupPortaudioLib()`, `sudoSetupAlsaLib()`, `sudoSetupGtk3Lib()`,
    and `sudoAptGetInstall(packages)` under the last one.
  - `package:tekartik_ci/ci_github.dart` — `bool get runningInGithubActions`.
  - `package:tekartik_ci/ci.dart` — empty placeholder, nothing to import.
  - `package:tekartik_ci/ci_flutter.dart` — `setup()`, `generate()`,
    `flutterTest()`, all `@Deprecated('To remove')`. Do not use them in new
    code; drive Flutter from `package:process_run` directly.
* The four `sudoSetup*Lib()` functions are **no-ops off Linux** (they check
  `Platform.isLinux`). The three older ones run a plain `sudo apt-get update`
  plus `sudo apt-get -y install <dev package>` through `package:process_run`'s
  `run`; `sudoSetupGtk3Lib` goes through `sudoAptGetInstall`. A failing
  `apt-get` throws: the executable exits non zero and the job fails. They assume an Ubuntu runner with password-less sudo, so call them
  from CI only, never from an application or a developer machine script.
  Mapping: `libsqlite3-dev` (fixes `Failed to load dynamic library
  'libsqlite3.so'`, i.e. `sqlite3`/`sqflite_common_ffi`), `portaudio19-dev`
  (`libportaudio.so`), `libasound2-dev` (`libasound.so`, needed by
  `flutter_soloud` and `flutter_sound`), `libgtk-3-dev libx11-dev
  libxi-dev` (`sudoSetupGtk3Lib`: `pkg-config --cflags gtk+-3.0 x11 xi
  failed` from the nativeapi build hook that `flutter test` runs, i.e.
  `window_manager` >= 0.6.0).
* `sudoAptGetInstall(packages)` (`sudoSetupGtk3Lib` uses it, new helpers
  should too) rejects anything but a package name, skips the packages
  already installed (no sudo at all when none is missing) and runs apt-get
  non interactive, waiting for the dpkg lock and retrying the downloads.
* Matching executables declared in `pubspec.yaml`: `setup_sqlite3lib`,
  `setup_portaudiolib`, `setup_alsalib`, `setup_gtk3lib`. The reusable
  `run_ci_flutter_jobs.yml` runs them before its tests when listed in its
  `tekartik-ci-setup` input (`tekartik-ci-setup: setup_gtk3lib`). Each `bin/*.dart` is a two-line
  `main` awaiting the corresponding function — copy that shape for a new
  library.
* `runningInGithubActions` is `Platform.environment['GITHUB_ACTIONS'] ==
  'true'` (via `tekartik_platform_io`'s `platformIo.runningOnGithub`). Use it
  to skip tests that need a real display, network or sudo, or to only install
  system packages on the runner. It is `dart:io` based: do not import
  `ci_github.dart` from web or Flutter-web code.
* Workflows: a public repository copies, as they are, two workflow
  templates from `tekartik/ci.dart/.github/workflows`:
  `run_ci_workflow_dart_all_platform.yml` (dart) or
  `run_ci_workflow_flutter_all_platform.yml` (flutter), plus
  `run_ci_workflow_flutter_analyze.yml` (analyze after pub get and after
  pub downgrade). A private flutter repository copies
  `run_ci_workflow_flutter_default.yml` (ubuntu stable only). They call the
  reusable workflows `run_ci_dart_jobs.yml` / `run_ci_flutter_jobs.yml`
  (one job per step: pub get, analyze, format, test, build) by the moving
  `@v1` tag. Their triggers: `push` with `branches: ['**']` (not on tag
  pushes) and `paths-ignore: ['**.md']` (not on doc only changes),
  `workflow_dispatch`, a weekly `schedule` for public repositories. See the
  repository README for the full list.
* `run_ci_flutter_jobs.yml` takes a `tekartik-ci-setup` input: space
  separated setup executables (`setup_gtk3lib`, `setup_sqlite3lib`...) run
  before the tests (names checked against `setup_[a-z0-9_]+`). The dart
  jobs workflow has no such input: add a step in your own workflow.
* Older composite actions, still working:
  `tekartik/ci.dart/.github/actions/run_ci_dart@v1` (checkout, Dart SDK,
  `dart run dev_build:run_ci@ --recursive`), `.../run_ci_flutter@v1`,
  `.../run_ci_flutter_analyze@v1` (pub downgrade + analyze, then pub upgrade
  + analyze), and `.../setup_ci_dart@v1`, `.../setup_ci_flutter@v1`,
  `.../run_ci_no_setup@v1`, `.../setup_ci_dart_latest@v1`,
  `.../run_ci_dart_latest@v1`. Inputs (all optional): `dart-channel` /
  `flutter-channel` (`stable`), `cache` (`true`), `cache-key-prefix`
  (`flutter`), `working-directory` (`.`), `checkout-token`
  (`${{ github.token }}`, set it for private repos).
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

### Workflow: flutter repository needing GTK on linux

`.github/workflows/run_ci_workflow_flutter_all_platform.yml`, the ci.dart
template with the setup input on its ubuntu jobs:

```yaml
name: Run CI workflow flutter all platform
on:
  push:
    branches: ['**'] # Not on tag pushes
    paths-ignore: ['**.md'] # Not on doc only changes
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # every sunday at midnight

jobs:
  ubuntu_stable:
    name: ubuntu stable
    uses: tekartik/ci.dart/.github/workflows/run_ci_flutter_jobs.yml@v1
    with:
      channel: stable
      runs-on: ubuntu-latest
      tekartik-ci-setup: setup_gtk3lib
  windows_stable:
    name: windows stable
    uses: tekartik/ci.dart/.github/workflows/run_ci_flutter_platform_jobs.yml@v1
    with:
      channel: stable
      runs-on: windows-latest
```

### Workflow: a step installing a library before your own CI

```yaml
name: Run CI dart
on:
  push:
    branches: ['**'] # Not on tag pushes
    paths-ignore: ['**.md'] # Not on doc only changes
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Install libsqlite3
        run: |
          dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
          dart pub global run tekartik_ci:setup_sqlite3lib
      - name: Run CI dart
        uses: tekartik/ci.dart/.github/actions/run_ci_dart@v1
        with:
          dart-channel: stable
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
* Referencing the actions or workflows with `@master` instead of `@v1`.
* A `push:` trigger without `branches: ['**']` and `paths-ignore: ['**.md']`:
  the workflow then also runs on tag pushes and doc only changes.
