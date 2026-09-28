# Workflow templates for consumer repositories (spec / ideas)

Status: proposal, 2026-09-28. The `@v1` references below exist today unless
marked *proposed*. See [ci_on_demand_testing.md](ci_on_demand_testing.md)
for how the templates get tested.

## Picking a template

| Repository | Template                                  | Runners                                                  | Cost driver                                   |
|------------|-------------------------------------------|----------------------------------------------------------|-----------------------------------------------|
| private    | `private_dart.yml`, `private_flutter.yml` | ubuntu stable, one job                                   | every job is billed, rounded up to the minute |
| public     | `public_dart.yml`                         | ubuntu stable/beta/dev, windows stable, macos stable     | free, only wall time and cache size matter    |
| public     | `public_flutter.yml`                      | analyze (pub get + pub downgrade) on ubuntu, then ubuntu stable/beta, windows stable, macos stable | same |
| public, experiment | `public_dart_small.yml`, `public_flutter_small.yml` | ubuntu stable, jobs split                     | same, less noise                              |

Why one job for private repositories: the jobs workflows split a run into
5 jobs (pub get, analyze, format, test, build) plus the setup of each; on a
private repository each of them is billed at least one minute, so a 40s
`run_ci` costs 5+ minutes instead of 1. Windows counts about 2x, macos about
10x. Public repositories pay nothing on standard runners, so there the split
(one status per step in the UI, parallel steps) is pure gain.

Conventions shared by all templates:

- Triggers: `push` on every branch but not on tags, doc only changes
  ignored, `workflow_dispatch` always (so the dispatch tool works), weekly
  `schedule` only where runs are free.
- `@v1`: the moving tag of ci.dart. Pin `@v1.0.7` instead when a repository
  must not follow.
- The reusable jobs workflows own the per job `timeout-minutes` (input,
  default 30) and a `concurrency` group that cancels an older run of the same
  caller/ref/os/sdk. Action based templates set both themselves.
- `dev_build:run_ci --recursive` runs in every package of the repository;
  exclude a folder with a `dev_build_run_ci_config.yaml` (`exclude: [.]` in
  the folder to skip).

## Private repositories

### `private_dart.yml` (today)

```yaml
# Private repository: one ubuntu job, no schedule (every run is billed).
name: Run CI
on:
  push:
    branches: ['**'] # Not on tag pushes
    paths-ignore: ['**.md'] # Not on doc only changes
  workflow_dispatch:

# A new run on the same ref cancels the older one.
concurrency:
  group: ${{ github.workflow_ref }}
  cancel-in-progress: true

jobs:
  ci:
    name: Run ci
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Run ci dart
        uses: tekartik/ci.dart/.github/actions/run_ci_dart@v1
```

The action checks out, installs dart stable, activates `dev_build` and runs
`dev_build:run_ci --recursive`. Its `dart-channel` input is currently
ignored (it reads `matrix.dart-channel`), which is harmless here since
stable is the default.

### `private_flutter.yml` (today)

Same file with the flutter action:

```yaml
name: Run CI
on:
  push:
    branches: ['**'] # Not on tag pushes
    paths-ignore: ['**.md'] # Not on doc only changes
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow_ref }}
  cancel-in-progress: true

jobs:
  ci:
    name: Run ci
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Run ci flutter
        uses: tekartik/ci.dart/.github/actions/run_ci_flutter@v1
```

To keep a private flutter repository honest about its constraints without
paying for a second workflow, add the downgrade leg as a second step in the
same job rather than a second job:

```yaml
      - name: Downgrade and analyze
        run: dart pub global run dev_build:run_ci --pub-downgrade --analyze --no-override --recursive
```

### Single job reusable workflows (proposed)

`run_ci_dart_job.yml` and `run_ci_flutter_job.yml`, `workflow_call` twins of
the jobs workflows but with everything in one job. They give private
repositories the 3 line caller and the same inputs (`sdk`/`channel`,
`runs-on`, `timeout-minutes`, `cache`) as the public ones, and they read
`inputs.*` so the channel bug of the composite actions does not apply.

```yaml
# Proposed tekartik/ci.dart/.github/workflows/run_ci_dart_job.yml
name: Run CI dart job
on:
  workflow_call:
    inputs:
      sdk:
        description: 'Dart sdk channel or version (stable, beta, dev, 3.13.x...)'
        type: string
        required: false
        default: 'stable'
      runs-on:
        description: 'Runner (ubuntu-latest, windows-latest, macos-latest)'
        type: string
        required: false
        default: 'ubuntu-latest'
      timeout-minutes:
        description: 'Timeout of the job in minutes'
        type: number
        required: false
        default: 30

permissions:
  contents: read

concurrency:
  group: run-ci-dart-job-${{ github.workflow_ref }}-${{ inputs.runs-on }}-${{ inputs.sdk }}
  cancel-in-progress: true

jobs:
  ci:
    name: Run ci
    runs-on: ${{ inputs.runs-on }}
    timeout-minutes: ${{ inputs.timeout-minutes }}
    steps:
      - uses: actions/checkout@v7
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: ${{ inputs.sdk }}
      - name: Cache pub
        uses: actions/cache@v6
        with:
          path: |
            ~/.pub-cache
            ~/AppData/Local/Pub/Cache
          key: dart-pub-${{ runner.os }}-${{ runner.arch }}-${{ inputs.sdk }}-${{ hashFiles('**/pubspec.yaml') }}
          restore-keys: |
            dart-pub-${{ runner.os }}-${{ runner.arch }}-${{ inputs.sdk }}-
      - run: dart --version
      - run: dart run dev_build:run_ci@ --recursive
```

The private caller then becomes:

```yaml
name: Run CI
on:
  push:
    branches: ['**'] # Not on tag pushes
    paths-ignore: ['**.md'] # Not on doc only changes
  workflow_dispatch:

jobs:
  ci:
    name: Run ci
    uses: tekartik/ci.dart/.github/workflows/run_ci_dart_job.yml@v1
```

Private git dependencies (a private package depending on another private
repository) need credentials for `pub get`; neither the actions nor the
reusable workflows handle it today (`checkout-token` only covers the checkout
of the repository itself). See the open questions of the testing document.

## Public repositories

### `public_dart.yml` (today, = ci.dart `run_ci_workflow_dart_all.yml`)

```yaml
name: Run CI dart
on:
  push:
    branches: ['**'] # Not on tag pushes
    paths-ignore: ['**.md'] # Not on doc only changes
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # every sunday at midnight

# One job per os/sdk (no matrix) so that each one is displayed as its own
# group (pub get then analyze, format, test, build) in the workflow graph.
jobs:
  ubuntu_stable:
    name: ubuntu stable
    uses: tekartik/ci.dart/.github/workflows/run_ci_dart_jobs.yml@v1
    with:
      sdk: stable
      runs-on: ubuntu-latest

  ubuntu_beta:
    name: ubuntu beta
    uses: tekartik/ci.dart/.github/workflows/run_ci_dart_jobs.yml@v1
    with:
      sdk: beta
      runs-on: ubuntu-latest

  ubuntu_dev:
    name: ubuntu dev
    uses: tekartik/ci.dart/.github/workflows/run_ci_dart_jobs.yml@v1
    with:
      sdk: dev
      runs-on: ubuntu-latest

  windows_stable:
    name: windows stable
    uses: tekartik/ci.dart/.github/workflows/run_ci_dart_jobs.yml@v1
    with:
      sdk: stable
      runs-on: windows-latest

  macos_stable:
    name: macos stable
    uses: tekartik/ci.dart/.github/workflows/run_ci_dart_jobs.yml@v1
    with:
      sdk: stable
      runs-on: macos-latest
```

### `public_flutter.yml` (today, one file: analyze + all)

Combines ci.dart `run_ci_workflow_flutter_analyze.yml` and
`run_ci_workflow_flutter_all.yml` in one workflow so a repository has a
single CI file. The two reusable workflows use different concurrency group
prefixes, so they do not cancel each other.

```yaml
name: Run CI flutter
on:
  push:
    branches: ['**'] # Not on tag pushes
    paths-ignore: ['**.md'] # Not on doc only changes
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # every sunday at midnight

# One job per os/channel (no matrix) so that each one is displayed as its own
# group (pub get then analyze, format, test, build) in the workflow graph.
jobs:
  analyze:
    # analyze after pub get and after pub downgrade (with --no-override)
    name: analyze
    uses: tekartik/ci.dart/.github/workflows/run_ci_flutter_analyze_jobs.yml@v1

  ubuntu_stable:
    name: ubuntu stable
    uses: tekartik/ci.dart/.github/workflows/run_ci_flutter_jobs.yml@v1
    with:
      channel: stable
      runs-on: ubuntu-latest

  ubuntu_beta:
    name: ubuntu beta
    uses: tekartik/ci.dart/.github/workflows/run_ci_flutter_jobs.yml@v1
    with:
      channel: beta
      runs-on: ubuntu-latest

  windows_stable:
    name: windows stable
    uses: tekartik/ci.dart/.github/workflows/run_ci_flutter_jobs.yml@v1
    with:
      channel: stable
      runs-on: windows-latest
      # The flutter sdk cache is ~2GB per os/channel and the repository cache
      # is limited to 10GB: skip it on the less used os.
      cache: false

  macos_stable:
    name: macos stable
    uses: tekartik/ci.dart/.github/workflows/run_ci_flutter_jobs.yml@v1
    with:
      channel: stable
      runs-on: macos-latest
      cache: false
```

Notes:

- The analyze legs run with `--no-override`, so `pubspec_overrides.yaml`
  files are ignored and the published constraints are what gets checked.
  The "latest" leg is `pub get`; with a committed `pubspec.lock` it is not an
  upgrade (open question in the testing document).
- With 4 os/channel groups the pub get handoff entries of a run can be
  evicted from the cache; the consumer jobs then run pub get again (a
  `::notice::` in the log), it is not a failure.

### `public_dart_small.yml` / `public_flutter_small.yml` (today)

For experiment repositories: ubuntu stable only, still split in jobs.

```yaml
name: Run CI
on:
  push:
    branches: ['**'] # Not on tag pushes
    paths-ignore: ['**.md'] # Not on doc only changes
  workflow_dispatch:

jobs:
  ci:
    name: Run ci
    uses: tekartik/ci.dart/.github/workflows/run_ci_dart_jobs.yml@v1
```

Replace `run_ci_dart_jobs.yml` with `run_ci_flutter_jobs.yml` for flutter.

## Where the templates live in ci.dart

Proposal: a `templates/` folder at the root of ci.dart holding the files
above under their template name (`templates/private_dart.yml`...), so that
"copy this file" is the whole instruction and the README only links them.
They cannot sit in `.github/workflows` since ci.dart's own workflows have
different triggers (dispatch/schedule only, see the testing document).

- The smoke workflow lints `templates/*.yml` with actionlint together with
  `.github`.
- Idea: ci.dart's own `run_ci_workflow_*.yml` are the templates with the
  `push:` trigger removed; a small tool can generate them from `templates/`
  (or a test can assert the `jobs:` sections are identical) so the two never
  drift.
- The public test repository (testing document, section 4 B) uses the
  templates verbatim as its workflows, which is the real test of the
  templates.

## Trying a template locally

With act (testing document, section 5), from a clean checkout of the
consumer repository, ubuntu jobs only:

```
gh act workflow_dispatch -W /path/to/ci.dart/templates/public_dart.yml \
  --local-repository "tekartik/ci.dart@v1=/path/to/ci.dart"
```

`--local-repository` makes the `@v1` references (reusable workflows and
actions, nested ones included) point at the local ci.dart checkout, so a
template can be tried against unreleased changes. The flutter templates
download the flutter sdk in every job when `cache: false` is set, count a
few minutes.

## Migrating an existing consumer

- Action based (`run_ci_dart@v1` with a matrix): replace the file with
  `public_dart.yml`. Matrix entries `beta`/`dev` were silently running
  stable with the action, expect new failures on the beta/dev groups.
- `run_ci_flutter_analyze@v1`: replace with the `analyze` job of
  `public_flutter.yml` (the downgrade leg is now a separate job chain).
- Private repositories with a matrix: keep only the ubuntu stable entry and
  drop the schedule, or move to `private_dart.yml`.
