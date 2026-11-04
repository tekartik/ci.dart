# ci.dart

CI helper for flutter dart projects

## Default for a public dart repository

Copy these two workflows, as they are, from this repository's
[`.github/workflows`](.github/workflows) into the `.github/workflows` folder
of the repository, and remove its older CI workflows (an action based
`run_ci.yml`, a `run_ci_downgrade_analyze.yml`...):

| Workflow | Runs |
|----------|------|
| [`run_ci_workflow_dart_all_platform.yml`](.github/workflows/run_ci_workflow_dart_all_platform.yml) | ubuntu stable, beta and dev: pub get, then analyze, format, test and build as separate jobs ([`run_ci_dart_jobs.yml`](.github/workflows/run_ci_dart_jobs.yml)); windows and macos stable: only the platform specific part, vm test and the builds but the web one, none for now ([`run_ci_dart_platform_jobs.yml`](.github/workflows/run_ci_dart_platform_jobs.yml)) |
| [`run_ci_workflow_flutter_analyze.yml`](.github/workflows/run_ci_workflow_flutter_analyze.yml) | analyze after pub get and after pub downgrade, with `--no-override` ([`run_ci_flutter_analyze_jobs.yml`](.github/workflows/run_ci_flutter_analyze_jobs.yml)): the published constraints are checked at both ends (after the downgrade, analyze fails on errors only: `--no-fatal-warnings`), `pubspec_overrides.yaml` files are ignored. The flutter sdk analyzes pure dart packages too |

Both run `dart run dev_build:run_ci@ ... --recursive`, so every package of
the repository is covered (exclude a folder with a
`dev_build_run_ci_config.yaml`). Triggers: a push on any branch (not on
tags, not on doc only changes), `workflow_dispatch`, every sunday. The
reusable workflows own the per job timeout (30 minutes) and a concurrency
group cancelling an older run of the same ref.

Example: [tekartik/firebase_functions.dart](https://github.com/tekartik/firebase_functions.dart/tree/master/.github/workflows).

Notes when migrating from the action based workflows below:

- beta and dev really run beta and dev: the actions read the channel from
  `matrix.*-channel` instead of their input, so a matrix entry `beta` or
  `dev` silently ran stable. Expect new findings there (newer lints, newer
  formatter).
- Windows and macos no longer repeat analyze, format and the web tests and
  build of ubuntu: same coverage of what differs per platform, fewer
  minutes.
- Each job is its own status in the UI. A pub get result is handed to the
  next jobs through the actions cache; when the entry is evicted, the job
  runs pub get again (a `::notice::` in the log), it is not a failure.
- "Re-run failed jobs" reuses the pub get of the first attempt: a fix pushed
  meanwhile to a git dependency is not picked up, re-run all jobs instead.
- `@v1` follows the releases of ci.dart (see [Releasing](#releasing)), pin a
  version tag (`@v1.0.9`) to stay on one.

The other templates (private repositories, small experiments) are in
[doc/workflow_templates.md](doc/workflow_templates.md).

## Default for a public flutter repository

The current best CI for a public flutter repository (2026-10-29): copy
these two workflows, as they are, from this repository's
[`.github/workflows`](.github/workflows) into the `.github/workflows` folder
of the repository, and remove its older CI workflows (an action based
`run_ci_flutter.yml` / `run_ci.yml`, a `run_ci_flutter_downgrade_analyze.yml`):

| Workflow | Runs |
|----------|------|
| [`run_ci_workflow_flutter_all_platform.yml`](.github/workflows/run_ci_workflow_flutter_all_platform.yml) | ubuntu stable and beta: pub get, then analyze, format, test and build (`flutter build web` for the flutter packages) as separate jobs ([`run_ci_flutter_jobs.yml`](.github/workflows/run_ci_flutter_jobs.yml)); windows and macos stable: only the platform specific part, vm test (`flutter test`, `dart test -p vm` for the pure dart packages) and the builds but the web one, none for now ([`run_ci_flutter_platform_jobs.yml`](.github/workflows/run_ci_flutter_platform_jobs.yml)) |
| [`run_ci_workflow_flutter_analyze.yml`](.github/workflows/run_ci_workflow_flutter_analyze.yml) | analyze after pub get and after pub downgrade, with `--no-override` ([`run_ci_flutter_analyze_jobs.yml`](.github/workflows/run_ci_flutter_analyze_jobs.yml)), the same file as for a dart repository |

Same as for a dart repository: `dart run dev_build:run_ci@ ... --recursive`
covers every package (a `dev_build_run_ci_config.yaml` excludes a folder),
same triggers, timeouts and concurrency, same notes when migrating.

For a flutter repository in particular:

- No `actions/setup-java` step: the build job only builds for the web, java
  (and the android sdk) is not needed. Dependabot then has no
  `actions/setup-java` to bump in the repository.
- No native setup step either (the old `setup_env.dart` installing
  `libsqlite3-dev`): `package:sqlite3` 3.x bundles its native library.
- Tests needing a native library on linux: pass the tekartik_ci setup
  executables (`ci/bin`) to the ubuntu jobs, run before the tests, e.g.
  `tekartik-ci-setup: setup_gtk3lib` for the native build hooks of
  `window_manager` >= 0.6.0 (see
  [tekartik/app_flutter_utils.dart](https://github.com/tekartik/app_flutter_utils.dart/tree/master/.github/workflows)).
- The flutter sdk and the pub cache are cached per os and channel (about
  2GB each, `cache` input of the reusable workflows).

Examples: [tekartik/app_flutter_utils.dart](https://github.com/tekartik/app_flutter_utils.dart/tree/master/.github/workflows),
[tekartik/common_flutter.dart](https://github.com/tekartik/common_flutter.dart/tree/main/.github/workflows).

## Default for a private flutter repository

A private repository (tekaly/festenaoprv for example) copies the single
[`run_ci_workflow_flutter_default.yml`](.github/workflows/run_ci_workflow_flutter_default.yml):
ubuntu stable only, run ci as separate jobs (pub get, analyze, format, test,
build: [`run_ci_flutter_jobs.yml`](.github/workflows/run_ci_flutter_jobs.yml)),
a push on any branch, `workflow_dispatch`, and a monthly schedule (day 28)
instead of a weekly one. No beta, no windows nor macos, no downgrade
analyze: every minute of a private repository is billed (a job is rounded up
to the minute, windows counts about 2x, macos about 10x). While the private
Actions credit is out, comment its `push` trigger and run it by hand
(`workflow_dispatch`).

## Reusable CI Actions

Older, action based workflows (one job per os/sdk, the whole `run_ci` in
it). Prefer the reusable workflows above for a public repository.

### Dart CI

Add the following workflow to your repository at `.github/workflows/run_ci.yml`:

```yaml
name: Run CI dart
on:
  push:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # every sunday at midnight

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
          - os: ubuntu-latest
            dart: dev
          - os: windows-latest
            dart: stable
          - os: macos-latest
            dart: stable
    steps:
      - name: Run CI dart
        uses: tekartik/ci.dart/.github/actions/run_ci_dart@v1
        with:
          dart-channel: ${{ matrix.dart }}
```

The `run_ci_dart` action:

- Checks out the repository
- Sets up the Dart SDK for the specified channel/version (`stable`, `beta`, `dev`, or a specific version like `3.24.x`)
- Runs `dart run dev_build:run_ci@ --recursive` (latest `dev_build` from pub.dev, no global activation)

Optional inputs:

| Input               | Default        | Description                                   |
|---------------------|----------------|-----------------------------------------------|
| `dart-channel`      | `stable`       | Dart channel or version                       |
| `cache`             | `true`         | Enable pub cache                              |
| `cache-key-prefix`  | `flutter`      | Prefix for cache key                          |
| `working-directory` | `.`            | Directory where pub get runs                  |
| `checkout-token`    | `github.token` | Token for checkout (useful for private repos) |

### Flutter CI

Add the following workflow to your repository at `.github/workflows/run_ci.yml`:

```yaml
name: Run CI flutter
on:
  push:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # every sunday at midnight

jobs:
  test:
    name: Test on ${{ matrix.os }} / ${{ matrix.flutter }}
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - os: ubuntu-latest
            flutter: stable
          - os: ubuntu-latest
            flutter: beta
          - os: windows-latest
            flutter: stable
          - os: macos-latest
            flutter: stable
    steps:
      - name: Run CI flutter
        uses: tekartik/ci.dart/.github/actions/run_ci_flutter@v1
        with:
          flutter-channel: ${{ matrix.flutter }}
```

The `run_ci_flutter` action:

- Checks out the repository
- Sets up the Flutter SDK for the specified channel/version (`stable`, `beta`, `master`, or a specific version like
  `3.24.x`)
- Runs `dart run dev_build:run_ci@ --recursive` (latest `dev_build` from pub.dev, no global activation)

Optional inputs:

| Input               | Default        | Description                                   |
|---------------------|----------------|-----------------------------------------------|
| `flutter-channel`   | `stable`       | Flutter channel or version                    |
| `cache`             | `true`         | Enable pub cache                              |
| `cache-key-prefix`  | `flutter`      | Prefix for cache key                          |
| `working-directory` | `.`            | Directory where pub get runs                  |
| `checkout-token`    | `github.token` | Token for checkout (useful for private repos) |

### Flutter Analyze (downgrade and upgrade)

Runs a downgrade+analyze followed by an upgrade+analyze to verify dependency compatibility at both ends. Add the following workflow to your repository:

```yaml
name: Analyze Flutter (downgrade and upgrade)
on:
  push:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # every sunday at midnight

jobs:
  analysis:
    runs-on: ubuntu-latest
    steps:
      - name: Full flutter analysis
        uses: tekartik/ci.dart/.github/actions/run_ci_flutter_analyze@v1
        with:
          flutter-channel: stable
```

The `run_ci_flutter_analyze` action:

- Checks out the repository
- Sets up the Flutter SDK for the specified channel/version
- Activates `dev_build`
- Runs `pub downgrade` then `analyze` recursively (errors only, `--no-fatal-warnings`)
- Runs `pub upgrade` then `analyze` recursively

Optional inputs:

| Input               | Default        | Description                                   |
|---------------------|----------------|-----------------------------------------------|
| `flutter-channel`   | `stable`       | Flutter channel or version                    |
| `cache`             | `true`         | Enable pub cache                              |
| `cache-key-prefix`  | `flutter`      | Prefix for cache key                          |
| `working-directory` | `.`            | Directory where pub get runs                  |
| `checkout-token`    | `github.token` | Token for checkout (useful for private repos) |

## Releasing

Workflows reference the actions through the `@v1` tag. GitHub resolves that tag
to a commit and runs the action definition from *that* snapshot, so changes
pushed to `master` have no effect on consumers until `v1` is moved.

To release:

1. Bump `version:` in `repo_support/pubspec.yaml`
2. Commit and push the changes on `master`
3. Tag and move `v1`:

   ```
   cd repo_support
   dart run tool/new_tag_current_and_v1_and_push.dart
   ```

The tool reads the version from `repo_support/pubspec.yaml`, creates the
matching `vX.Y.Z` tag, repoints `v1` to it and pushes both. It aborts if the
version tag already exists, so bump the version first.

To move `v1` only, without creating a version tag:

```
cd repo_support
dart run tool/tag_v1_and_push.dart
```

New runs pick up the moved tag immediately, there is no action cache to clear.
