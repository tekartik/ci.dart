# ci.dart

CI helper for flutter dart projects

## Default for a public dart repository

Copy these two workflows, as they are, from this repository's
[`.github/workflows`](.github/workflows) into the `.github/workflows` folder
of the repository, and remove its older CI workflows (an action based
`run_ci.yml`, a `run_ci_downgrade_analyze.yml`...):

| Workflow | Runs |
|----------|------|
| [`run_ci_workflow_dart_all_platform.yml`](.github/workflows/run_ci_workflow_dart_all_platform.yml) | ubuntu stable, beta and dev: pub get, then analyze, format, test and build as separate jobs ([`run_ci_dart_jobs.yml`](.github/workflows/run_ci_dart_jobs.yml)); windows and macos stable: only the platform specific part, pub get and vm test ([`run_ci_dart_platform_jobs.yml`](.github/workflows/run_ci_dart_platform_jobs.yml)) |
| [`run_ci_workflow_flutter_analyze.yml`](.github/workflows/run_ci_workflow_flutter_analyze.yml) | analyze after pub get and after pub downgrade, with `--no-override` ([`run_ci_flutter_analyze_jobs.yml`](.github/workflows/run_ci_flutter_analyze_jobs.yml)): the published constraints are checked at both ends, `pubspec_overrides.yaml` files are ignored. The flutter sdk analyzes pure dart packages too |

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

A flutter repository has the twin
[`run_ci_workflow_flutter_all_platform.yml`](.github/workflows/run_ci_workflow_flutter_all_platform.yml)
(with the same analyze workflow). The other templates (private
repositories, small experiments) are in
[doc/workflow_templates.md](doc/workflow_templates.md).

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
- Runs `pub downgrade` then `analyze` recursively
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
