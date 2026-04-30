# ci.dart

CI helper for flutter dart projects

## Reusable CI Actions

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
- Activates `dev_build` and runs `dart pub global run dev_build:run_ci --recursive`

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
- Activates `dev_build` and runs `dart pub global run dev_build:run_ci --recursive`

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
