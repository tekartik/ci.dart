# On demand CI testing for ci.dart (spec / ideas)

Status: proposal, 2026-09-28. Nothing below is implemented yet unless marked
*(exists)*.

Companion document: [workflow_templates.md](workflow_templates.md) (the
workflows consumer repositories copy).

## Goals

- A push to ci.dart must not start every workflow: today 23 workflows run on
  every branch push, several of them with 4-5 os/sdk groups of 5 jobs each.
- From the terminal, in one command, try a workflow or an action:
  - as it is on `master` (before moving `v1`),
  - as consumers get it (`@v1`),
  - at a given tag (`v1.0.6`) or at a given revision (any sha).
- Know quickly (watch the run, get the failed logs) without opening the
  browser.
- Try the ubuntu jobs locally, before pushing anything (section 5).
- Keep the copy/paste workflows for consumers simple and, for private
  repositories, cheap.
- Decide whether ci.dart alone is enough as a test bed or whether a separate
  public test repository is needed (github_actions_dart_prv got too expensive
  and its workflows are disabled).

## Current state (2026-09-28)

- `.github/workflows` holds 23 workflows, all with the same triggers:
  `push: branches: ['**']` (no tag pushes) + `paths-ignore: ['**.md']`,
  `workflow_dispatch`, weekly `schedule`.
- Three families:
  - `run_ci_workflow_*.yml`: callers of the reusable jobs workflows through
    `tekartik/ci.dart/.github/workflows/run_ci_{dart,flutter,flutter_analyze}_jobs.yml@v1`
    (what consumers get).
  - `run_ci_workflow_local_*.yml`: same callers but `uses: ./.github/workflows/...`
    (what `master`, or the dispatched ref, would give once `v1` moves).
  - `run_ci_action_*.yml`, `run_ci.yml`, `run_ci_flutter*.yml`: the composite
    actions (`@v1`) and raw setups, marked "Prefer the new default".
- The reusable workflows and the composite actions reference the sibling
  actions with `tekartik/ci.dart/.github/actions/...@v1` (`uses:` cannot be
  an expression), so even a `local` workflow runs the `v1` version of
  `setup_ci_flutter`.
- Known reds: `Run CI action dart latest` fails on windows/macos
  (`setup_ci_dart_latest` lacks the `problem-matcher: false` workaround);
  `setup_ci_dart*` and `run_ci_*` actions read `matrix.*-channel` instead of
  `inputs.*-channel` so beta/dev matrix entries run stable.
- Releasing = bump `repo_support/pubspec.yaml`, push `master`, move `v1`
  (`repo_support/tool/new_tag_current_and_v1_and_push.dart`). Runs resolve
  `@v1` when they start.

## GitHub facts the design relies on (verified against the docs)

- `workflow_dispatch` "will only trigger a workflow run if the workflow file
  exists on the default branch". Once known, it can be dispatched "against
  any branch or tag": the workflow file *of that ref* runs.
- The dispatch `ref` "can be a branch or tag name". Not a sha. Testing a
  revision means tagging it.
- `gh workflow run` takes the workflow file name and `--ref`; inputs with
  `-f key=value`. A classic token needs the `repo` scope (the current `gh`
  login has it).
- A reusable workflow referenced with `./` "is from the same commit as the
  caller workflow". A local action (`uses: ./.github/actions/x`) is read from
  the job workspace, so it needs a checkout first and it is the version of
  whatever ref was checked out.
- `push` with only `branches` filters never runs on tag pushes, so temporary
  tags cost nothing.
- Actions minutes are free for public repositories on standard runners.
  Private repositories: 2000 min/month on Free, each job rounded up to the
  minute, windows about 2x and macos about 10x the linux price.

## 1. Triggers: what runs on push, on schedule, on demand

Policy:

| Trigger              | What                                                                                    |
|----------------------|-----------------------------------------------------------------------------------------|
| `push` (any branch)  | one smoke workflow only                                                                 |
| `schedule` (weekly)  | every supported workflow (free, catches new SDK releases, one run each per week)        |
| `workflow_dispatch`  | every workflow, driven by the tool of section 2                                         |

Smoke workflow (`smoke.yml`, new):

- job `lint`: actionlint on `.github/**/*.yml` and on the templates (see the
  templates document), ubuntu, about 10s. Catches yaml/expression errors
  before anything is dispatched.
- job `ci`: `uses: ./.github/workflows/run_ci_dart_jobs.yml` (ubuntu stable,
  the version of the pushed commit). About 1-2 minutes wall time.
- `paths-ignore: ['**.md']` stays (doc only commits, like this one, run
  nothing).

Every other workflow loses its `push:` trigger and keeps `workflow_dispatch`
and (if still supported) `schedule`. Suggested cleanup while touching all the
files:

| Workflow                                  | Proposal                                                                          |
|-------------------------------------------|-----------------------------------------------------------------------------------|
| `run_ci_workflow_{dart,flutter}_{default,all}`, `run_ci_workflow_flutter_analyze` | dispatch + weekly (consumer view of `v1`)         |
| `run_ci_workflow_local_*`                 | dispatch + weekly (`master` view); `local_dart_default` is replaced by the smoke job |
| `run_ci_action_{dart,flutter}{,_default}`, `run_ci_action_flutter_analyze` | dispatch + weekly (most consumer repos still use the actions) |
| `run_ci_action_dart_latest`               | dispatch only until the windows/macos failure is fixed, then weekly               |
| `run_ci.yml` (tekartik_ci setup_*lib)     | keep, ubuntu only: the `sudoSetup*Lib` functions are no-ops off linux, the 4 other jobs only repeat what `run_ci_workflow_dart_all` covers |
| `run_ci_flutter.yml`, `run_ci_flutter_downgrade_analyze.yml` | drop (covered by the `run_ci_workflow_flutter_*` ones)         |
| `run_ci_flutter_with_setup.yml`           | dispatch only (`setup_ci_flutter@v1` + `run_ci_no_setup@v1`), or drop             |

Idea to avoid a 23-run queue every sunday: spread the crons (`0 0`, `0 1`,
`0 2 * * 0`), or keep the weekly schedule on the `*_all` and `*_analyze`
workflows only.

## 2. Dispatching from the terminal

### 2.1 What a ref changes, what it does not

Dispatching `W.yml` with `--ref R` runs the file `W.yml` as it is at `R`.
Inside it:

- `uses: ./.github/workflows/X.yml` is `X.yml` at `R`.
- `uses: ./.github/actions/X` (after a checkout) is the action at `R`.
- `actions/checkout` checks out `R`, so ci.dart's own packages are tested at
  `R`.
- `uses: tekartik/ci.dart/...@v1` is whatever `v1` points to when the run
  starts, whatever `R` is.

Which workflow answers which question:

| Question                                            | Workflow                                    | `--ref`            |
|-----------------------------------------------------|---------------------------------------------|--------------------|
| Does the reusable workflow on master work?          | `run_ci_workflow_local_dart_all`            | `master`           |
| Would my branch work once tagged?                   | `run_ci_workflow_local_*`                   | the branch         |
| Do consumers still pass with the current `v1`?      | `run_ci_workflow_dart_all`, `run_ci_action_*` | `master` (any)   |
| Does the leaf action on master work?                | a `*_local_*` workflow using `./.github/actions/x` (section 3) | `master` |
| Did `v1.0.6` still work?                            | any                                         | `v1.0.6`           |
| Does revision `abc1234` work?                       | any                                         | `ci-test/abc1234` (section 2.4) |

### 2.2 Manual commands (work today)

```
gh workflow run run_ci_workflow_local_dart_all.yml --ref master
gh run list --workflow run_ci_workflow_local_dart_all.yml --branch master --event workflow_dispatch -L 3
gh run watch <run-id> --exit-status --compact
gh run view <run-id> --log-failed
```

Gotchas seen with `gh`:

- `gh workflow run` prints no run id; the run appears in `gh run list` a few
  seconds after the dispatch.
- The workflow must exist on `master` (default branch) to be dispatchable at
  all, and exist *with `workflow_dispatch`* at the ref, otherwise the API
  answers 404/422.
- The jobs workflows have `concurrency: cancel-in-progress` keyed on
  `workflow_ref` + inputs: dispatching the same workflow twice on the same
  ref cancels the first run.
- `--branch` filters on the ref name, tags included (`headBranch` of a run
  dispatched on a tag is the tag name). `--commit <sha>` is more precise.

### 2.3 The tool: `repo_support/tool/gh_workflow_run.dart`

Written with `package:dev_build/shell.dart` (process_run `Shell`), drives
`gh`, no GitHub API code of our own.

```
dart run tool/gh_workflow_run.dart [options] <workflow>...

  <workflow>              file name, or any unique suffix of it
                          (local_dart_all = run_ci_workflow_local_dart_all.yml)
  -r, --ref <branch|tag>  default: the current branch (it must be pushed)
      --rev <sha>         tag ci-test/<sha7> at <sha>, push it, dispatch on it,
                          delete the tag when done (--keep-tag keeps it)
  -f <key>=<value>        workflow input (repeatable)
      --watch             (default) wait for the run, exit code = conclusion
      --no-watch          dispatch and print the run url only
      --logs              on failure, print `gh run view --log-failed`
      --all-local         every run_ci_workflow_local_*.yml
      --all-v1            every run_ci_workflow_*.yml and run_ci_action_*.yml
      --list              list the dispatchable workflows of the repository
      --local             run through act instead of dispatching (section 5.5)
      --repo <owner/repo> default: origin of the current checkout
```

Behaviour:

1. Resolve the workflow names against `.github/workflows/*.yml` files that
   contain `workflow_dispatch`.
2. Refuse a `--ref` branch that is not pushed (`git ls-remote origin <ref>`),
   refuse an unknown tag.
3. Dispatch every requested workflow first (they run in parallel on GitHub),
   then watch them one after the other.
4. Find each run: poll `gh run list --workflow <file> --branch <ref>
   --event workflow_dispatch --json databaseId,createdAt,url -L 5` every 3s
   until a run created after the dispatch time shows up (allow a few seconds
   of clock skew, give up after 60s).
5. `gh run watch <id> --exit-status --compact`; on failure and `--logs`,
   `gh run view <id> --log-failed`.
6. Print one line per workflow: conclusion, duration, url.

Sketch of the core (not compiled):

```dart
import 'dart:convert';

import 'package:dev_build/shell.dart';

Future<int> dispatchAndWatch(String workflow, String ref) async {
  var shell = Shell(verbose: false);
  var before = DateTime.now().toUtc().subtract(const Duration(seconds: 5));
  await shell.run('gh workflow run $workflow --ref ${shellArgument(ref)}');
  int? runId;
  while (runId == null) {
    await Future<void>.delayed(const Duration(seconds: 3));
    var out = (await shell.run('gh run list --workflow $workflow'
            ' --branch ${shellArgument(ref)} --event workflow_dispatch'
            ' --limit 5 --json databaseId,createdAt'))
        .outText;
    for (var run in (jsonDecode(out) as List).cast<Map>()) {
      if (DateTime.parse(run['createdAt'] as String).isAfter(before)) {
        runId = run['databaseId'] as int;
        break;
      }
    }
  }
  try {
    await shell.run('gh run watch $runId --exit-status --compact');
    return 0;
  } on ShellException {
    await shell.run('gh run view $runId --log-failed');
    return 1;
  }
}
```

Exact run identification (optional, later): give every dispatchable workflow
a `label` input and `run-name: ${{ inputs.label || github.workflow }}`; the
tool passes `-f label=gh-<timestamp>` and filters `gh run list --json
displayTitle` on it. No more time window, and the label shows in the Actions
UI.

Where it lives later: `tekartik_ci` (the `ci` package) as
`package:tekartik_ci/gh_workflow.dart` plus an executable
`gh_workflow_run`, so any repository (private ones with dispatch-only
workflows, section 5) triggers its CI with:

```
dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
dart pub global run tekartik_ci:gh_workflow_run run_ci --ref main
```

Phase 1 keeps it in `repo_support/tool` (ci.dart only), phase 2 moves it.

### 2.4 Testing a revision

`--rev <sha>`:

1. `git tag -f ci-test/<sha7> <sha>` and `git push -f origin ci-test/<sha7>`.
   The tag push triggers nothing (branch filters only). A branch would
   trigger the smoke workflow, hence tags.
2. Dispatch with `--ref ci-test/<sha7>`.
3. After the run, `git push origin :refs/tags/ci-test/<sha7>` and delete it
   locally, unless `--keep-tag`.

Constraint: the workflow file must exist at that revision with
`workflow_dispatch` (true for every workflow since the current set was
created). Stale tags: `git ls-remote --tags origin 'ci-test/*'`.

The same works by hand for a tag that already exists:
`gh workflow run run_ci_workflow_dart_all.yml --ref v1.0.6`.

## 3. Testing actions before moving `v1`

`uses:` is static and the composite actions call their siblings with `@v1`
(`run_ci_dart` -> `setup_ci_dart@v1`, `run_ci_flutter` and
`run_ci_flutter_analyze` -> `setup_ci_flutter@v1`, the flutter jobs
workflows -> `setup_ci_flutter@v1`). `./` cannot be used inside an action
consumed from another repository (it would resolve in the consumer's
workspace), so on GitHub the nesting edges can only be tested through `v1` (locally,
act's `--local-repository` substitutes them, section 5).

The leaves can be tested on `master` or on a revision: a local workflow that
checks out and uses the action with `./`:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: ./.github/actions/setup_ci_flutter   # the checked out version
      - uses: ./.github/actions/run_ci_no_setup
```

(`setup_ci_flutter` checks out again, harmless.)

Proposal, in order of effort:

1. Hand written `run_ci_action_local_*.yml` twins for the leaf actions
   (`setup_ci_dart`, `setup_ci_dart_latest`, `setup_ci_flutter`,
   `run_ci_no_setup`), dispatch + weekly. Together with the existing
   `run_ci_workflow_local_*`, everything but the one-line nesting edges is
   testable before tagging.
2. Local twins of the jobs workflows (`run_ci_flutter_jobs_local.yml`,
   `run_ci_flutter_analyze_jobs_local.yml`) where the `setup_ci_flutter@v1`
   steps become checkout + `./.github/actions/setup_ci_flutter`, called by
   the `run_ci_workflow_local_flutter_*` callers. Then a flutter setup
   change is fully tested on `master`.
3. Generate the local twins instead of maintaining them: a
   `repo_support/tool/generate_local_workflows.dart` that rewrites
   `tekartik/ci.dart/.github/workflows/X@v1` to `./.github/workflows/X` and
   `tekartik/ci.dart/.github/actions/X@v1` to a checkout step plus
   `./.github/actions/X`, with a "generated, do not edit" header, and a test
   (or the smoke lint job) checking they are up to date. Only worth it if
   keeping the twins in sync keeps hurting.

Fixing the `matrix.*-channel` bug and the `dart latest` windows/macos
failure should happen in the same move, since these actions are exercised
by step 1 anyway.

## 4. Is ci.dart enough as a test bed?

What ci.dart covers today: pure dart packages (`ci`, `ci_support`,
`repo_support`) on every os/sdk; the flutter toolchain path only as "dart
from the flutter sdk", since no package in the workspace uses flutter.
`flutter analyze/test/build web`, plugins and the
`.flutter-plugins-dependencies` cache path are never run (the private repo
had a `flutter_app/` for that).

Options:

A. Add a minimal flutter app to ci.dart (`ci_test/flutter_app`, `flutter
   create` web only, like the private repo had). The dart workflows already
   skip flutter packages when flutter is not installed. Cost: 1-2 minutes
   more per flutter job, free in a public repository. One repository, one
   tag, one dispatch tool.

B. A separate public test repository (`tekartik/ci_test.dart`, or move
   `alextekartik/github_actions_dart_prv` to public): a *consumer* of
   ci.dart, containing a dart package, a flutter app and the copied
   templates as its real workflows. Tests what ci.dart cannot test on
   itself: cross repository `@v1` resolution, `checkout-token`, a template
   copied verbatim. All workflows dispatch-only (or push on `main` only).
   The tool gets `--ci-ref <ref>` for that repository: on a temporary
   branch, rewrite `tekartik/ci.dart/...@v1` to `@<ref>` (a sha is allowed
   in `uses:`), push, dispatch, delete the branch. That is "test revision X
   exactly as a consumer would get it".

C. Keep `github_actions_dart_prv` dormant: its workflows back in
   `.github/workflows` but `workflow_dispatch` only and ubuntu only, so it
   costs nothing until dispatched. It is the only place to test private
   specifics (private git dependencies needing a token, the checkout token).

Recommendation: A now (it makes the flutter workflows meaningful at no
cost), B when the templates exist (the test repository's workflows *are* the
templates, so they cannot drift), C as is, dispatch only.

## 5. Testing locally on ubuntu with act

[nektos/act](https://github.com/nektos/act) runs the jobs of a workflow in
docker containers on the local machine. It emulates ubuntu runners only
(windows/macos jobs are skipped with "Skipping unsupported platform"), which
is the scope for now.

Verified on 2026-09-28 with act 0.2.89 (binary from the GitHub release, not
installed), docker 28.4 (no sudo needed on this machine) and the image
`catthehacker/ubuntu:act-latest` (the "medium" image: ubuntu 24.04, node,
curl, git, unzip, xz, sudo; no chrome, no java; runs as root), on a clean
clone of ci.dart (`d624d34`):

| Case                                                                                   | Result                                                                                                                                   |
|----------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| `run_ci_workflow_local_dart_default.yml` (`./` reusable workflow), dry run             | resolves the local `run_ci_dart_jobs.yml`, 5 jobs                                                                                        |
| `run_ci_workflow_dart_default.yml` (`@v1` remote reusable workflow), dry run           | act clones `tekartik/ci.dart@v1` into `~/.cache/act`, 5 jobs                                                                             |
| same, real run with `--local-repository tekartik/ci.dart@v1=$PWD`                      | 57s, 5 jobs green; a marker step added to the local `run_ci_dart_jobs.yml` was printed, so the local checkout replaced `v1`              |
| `run_ci_action_dart_default.yml` (`run_ci_dart@v1` calling `setup_ci_dart@v1`) with `--local-repository`, dry run | both levels read from the local folder: the nesting edges of section 3 are testable locally                   |
| `actions/cache/save` then `restore` handoff                                            | works through act's built in cache server, key `run-ci-pub-get-1-Linux-X64-stable` (`run_id` is 1 under act), cache hit in the 4 jobs   |
| second run, same cache directory                                                       | the key is saved again without error and restored, 42s                                                                                   |
| `dart-lang/setup-dart@v1`                                                              | 10s in the first job, 0.4s in the others: act shares `/opt/hostedtoolcache` between the containers of a run                              |
| `actions/checkout@v7`                                                                  | replaced by a copy of the working directory (0.1s)                                                                                       |
| `run_ci_workflow_local_dart_all.yml`, dry run                                          | ubuntu stable/beta/dev run, windows and macos jobs skipped                                                                               |
| a template file outside `.github/workflows` (`-W templates/public_dart.yml`), dry run  | works, the `@v1` references resolve in the local checkout; ubuntu jobs listed, windows/macos skipped                                     |
| `run_ci_workflow_local_flutter_default.yml` (`setup_ci_flutter@v1` -> subosito)        | 3m49s, 5 jobs green; subosito downloads the sdk once (1m9s), the 4 other jobs find it in the shared toolcache (0.6s), pub get handoff restored |
| a workflow without `actions/checkout` (probe running `ls -a`)                          | empty workspace: the copy happens at the checkout step                                                                                   |
| what the checkout step copies from the ci.dart root (same probe)                        | `.gitignore` honoured: no `pubspec_overrides.yaml`, `.dart_tool/`, `pubspec.lock`; `.git` and untracked files present                    |
| `repo_support/example/act_pub_get` minimal workflow (section 5.6)                       | 3.9s, checkout + setup-dart + `dart pub get` green, `+ path 1.9.1` resolved in the container                                             |
| `repo_support/tool/act_run.dart` in place (section 5.7)                                | dry run clean, `local_dart_default` 37s, 5 jobs green, dev_build resolved from pub.dev (the root overrides did not leak)                |

### 5.1 Setup

```
gh extension install nektos/gh-act        # act as `gh act`, fits the gh based tooling
docker pull catthehacker/ubuntu:act-latest
```

(or the `act` binary from the GitHub releases in `~/bin`). Then `~/.actrc`,
one flag per line, so the image never has to be given (without it the first
run asks interactively which image size to use and writes the file itself):

```
-P ubuntu-latest=catthehacker/ubuntu:act-latest
--pull=false
```

### 5.2 Commands

act copies the current folder into the container at the `actions/checkout`
step (a workflow without that step gets an empty workspace), honouring the
`.gitignore` files found in that folder (`--use-gitignore`, default true):
`pubspec_overrides.yaml`, `.dart_tool/` and `pubspec.lock` stay out, `.git`
and untracked files go in, so the working tree with its uncommitted changes
is what runs. A `.gitignore` above the folder is not read: a sub folder run
on its own (section 5.6) needs its own.

```
# what master gives (./ reusable workflow, local actions)
gh act workflow_dispatch -W .github/workflows/run_ci_workflow_local_dart_default.yml

# what consumers get, but with this checkout in place of v1, nested actions
# included (the only way to test the nesting edges before moving v1)
gh act workflow_dispatch -W .github/workflows/run_ci_workflow_dart_default.yml \
  --local-repository "tekartik/ci.dart@v1=$PWD"

# one os/sdk of an _all caller (windows/macos jobs are skipped anyway)
gh act workflow_dispatch -W .github/workflows/run_ci_workflow_local_dart_all.yml -j ubuntu_beta

# validate only (no container): reusable workflows and actions are resolved,
# jobs and steps listed
gh act workflow_dispatch -W .github/workflows/run_ci_workflow_local_dart_all.yml -n

# a template, from a consumer repository, against a local ci.dart
gh act workflow_dispatch -W /path/to/ci.dart/templates/public_dart.yml \
  --local-repository "tekartik/ci.dart@v1=/path/to/ci.dart"
```

Useful flags: `-j <job id>`, `-n` dry run, `--input k=v` for
`workflow_dispatch` inputs, `--cache-server-path <dir>` (default
`~/.cache/actcache`), `--action-offline-mode` (no refetch of `@v1` and of
the actions, faster and works offline), `-r`/`--reuse` keeps the containers
between runs, `--json`.

### 5.3 What act does not tell you

- windows/macos: skipped. Runner image differences: no chrome (the browser
  tests of `run_ci` do not run), no java, root user.
- `github.run_id` is always 1: the pub get handoff key is the same in every
  local run and the cache server keeps entries across runs. If the pub get
  job fails after a previous successful run, the consumer jobs still restore
  the old entry (cache hit). Wipe `--cache-server-path` (or point it to a
  temp dir) when the pub get job itself is what changed.
- Not simulated: cache eviction and the 10GB limit, `concurrency` and
  `cancel-in-progress`, `timeout-minutes`, `github.workflow_ref`, billing,
  the real `actions/checkout` (unless `--no-skip-checkout`, which then needs
  the ref pushed and a token for private repositories).
- Remote references (`@v1`, `dart-lang/setup-dart@v1`) are fetched into
  `~/.cache/act` and refreshed on each run unless `--action-offline-mode`.
- `gh act -l` on the whole workflows folder exits 2 ("multiple jobs with the
  same job name"), list with `-W <file>`.
- A caller referencing a reusable workflow that does not exist in the local
  checkout fails at once with `lstat ...: no such file or directory` (seen
  with the proposed `run_ci_dart_job.yml`): a cheap check that a template
  matches the ci.dart revision it is meant for.
- The containers use the host network, pub.dev is reached directly.

### 5.4 Other local options

- actionlint (static): yaml, expressions, `run:` scripts through shellcheck.
  Already in the smoke job. No execution, so nothing about the run itself.
- No yaml at all: the jobs only wrap `dart run dev_build:run_ci@ ...`, so
  `dart run dev_build:run_ci --recursive` (or `repo_support/tool/run_ci.dart`)
  tests the dart side. act adds the wiring: reusable workflow and action
  resolution, inputs, cache handoff, job graph.
- A self-hosted runner registered on the repository would run the real
  workflow on this machine (`runs-on` is an input of the jobs workflows, so
  `runs-on: self-hosted` is one line), free and with the real GitHub
  semantics. GitHub advises against self-hosted runners on public
  repositories (a fork's pull request can run code on the machine). Not for
  ci.dart, at most for the dormant private test repository.

### 5.5 In the tool

`repo_support/tool/act_run.dart` (section 5.7) is the standalone version,
`repo_support/tool/act_example_pub_get.dart` (section 5.6) the smallest one.
`gh_workflow_run.dart --local` runs the same `<workflow>` names through act
instead of dispatching: `gh act workflow_dispatch -W <file>
--local-repository tekartik/ci.dart@v1=<repo root> --cache-server-path
<temp dir>`, with `-j` and `--input` passed through, `gh act` if the
extension is installed else `act`. Same names locally and remotely:

```
dart run tool/gh_workflow_run.dart local_dart_default --local
dart run tool/gh_workflow_run.dart local_dart_default --ref master
```

### 5.6 Minimal example: a pub get workflow *(exists)*

`repo_support/example/act_pub_get` is a package reduced to a `pubspec.yaml`
(one dependency) with its own workflow and `.gitignore`, and
`repo_support/tool/act_example_pub_get.dart` runs it with act. Verified
2026-09-28: 3.9s, job green, `+ path 1.9.1` resolved in the container (the
dart sdk comes from act's tool cache after the first run).

```
cd repo_support
dart run tool/act_example_pub_get.dart              # first run pulls the image
dart run tool/act_example_pub_get.dart -n           # dry run
dart run tool/act_example_pub_get.dart --pull=false -v
```

`example/act_pub_get/.github/workflows/pub_get.yml` (GitHub never runs it,
only the root `.github/workflows` folder is read):

```yaml
# Minimal workflow for the act example (repo_support/tool/act_example_pub_get.dart):
# checkout, dart sdk, pub get.
#
# GitHub never runs it: workflows are only read from the .github/workflows
# folder at the root of the repository.
name: Pub get
on:
  workflow_dispatch:

jobs:
  pub_get:
    name: Pub get
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: dart-lang/setup-dart@v1
      - run: dart --version
      - run: dart pub get
```

`tool/act_example_pub_get.dart`: the script runs act *in* the example folder
(act copies the current folder at the checkout step) and passes its own
arguments on to act.

```dart
import 'package:dev_build/shell.dart';
import 'package:path/path.dart';

/// Run the minimal pub get workflow of `example/act_pub_get` with act.
///
///     dart run tool/act_example_pub_get.dart [act options]
///
/// act copies `example/act_pub_get` into an ubuntu container at the checkout
/// step, installs the dart sdk and runs `dart pub get` there. Extra arguments
/// go to act (`-n` dry run, `--pull=false`, `-v`...).
///
/// Needs docker and act (`gh extension install nektos/gh-act` or the `act`
/// binary in the path).
Future<void> main(List<String> args) async {
  var act = whichSync('act') != null ? 'act' : 'gh act';
  var shell = Shell(workingDirectory: join('example', 'act_pub_get'));
  await shell.run(
    '$act workflow_dispatch -W .github/workflows/pub_get.yml'
    ' -P ubuntu-latest=catthehacker/ubuntu:act-latest'
    ' ${shellArguments(args)}',
  );
}
```

### 5.7 Example: `repo_support/tool/act_run.dart` *(exists)*

A tool on `package:dev_build/shell.dart` (the process_run `Shell`) that runs
one ci.dart workflow through act. Verified 2026-09-28: dry run without a
warning, real run of `local_dart_default` in 37s with the 5 jobs green.

```
cd repo_support
dart run tool/act_run.dart local_dart_default       # real run, ubuntu stable
dart run tool/act_run.dart -n local_dart_all        # dry run, all ubuntu groups
dart run tool/act_run.dart -j ubuntu_beta local_dart_all
dart run tool/act_run.dart --no-local dart_default  # real v1, not this checkout
```

What it does:

- finds the workflow in `.github/workflows` by file name or unique suffix
  (`local_dart_default` is `run_ci_workflow_local_dart_default.yml`);
- uses `act` from the path, or `gh act` when the extension is installed;
- runs in place: act copies the repository at the checkout step honouring
  `.gitignore`, so the root `pubspec_overrides.yaml` (local paths here) and
  `.dart_tool/` stay out and the working tree, uncommitted changes included,
  is what runs;
- passes the ubuntu image, `--pull` only when the image is missing,
  `--cache-server-path .dart_tool/act_cache` (delete it when the pub get job
  itself changed) and `--local-repository tekartik/ci.dart@v1=<repo>`;
- runs act with `Shell(workingDirectory: root)`, `shellArguments` quoting
  the options, and reports the `ShellException` on failure.

```dart
import 'dart:io';

import 'package:args/args.dart';
import 'package:dev_build/shell.dart';
import 'package:path/path.dart';

/// Run a ci.dart workflow locally with act (ubuntu jobs only).
///
///     dart run tool/act_run.dart [options] <workflow>
///
/// `<workflow>` is a file of `.github/workflows`
/// (`run_ci_workflow_local_dart_default.yml`, or just `local_dart_default`).
///
/// - act copies the repository into the container at the checkout step,
///   `.gitignore` honoured: `pubspec_overrides.yaml`, `.dart_tool/` and
///   `pubspec.lock` stay out, untracked files go in.
/// - `tekartik/ci.dart@v1` references (reusable workflows and actions, nested
///   ones included) are replaced by this checkout, so the working tree is what
///   runs.
/// - The act cache (pub get handoff between jobs) lives in `.dart_tool/act_cache`
///   of the repository, delete it when the pub get job itself changed.
///
/// Needs docker and act (`gh extension install nektos/gh-act` or the `act`
/// binary in the path).
const image = 'catthehacker/ubuntu:act-latest';
const repository = 'tekartik/ci.dart@v1';

Future<void> main(List<String> args) async {
  var parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Usage')
    ..addFlag(
      'dry-run',
      abbr: 'n',
      negatable: false,
      help: 'Validate and list the jobs, no container',
    )
    ..addOption('job', abbr: 'j', help: 'Run one job id only (ubuntu_beta...)')
    ..addMultiOption('input', abbr: 'i', help: 'workflow_dispatch input k=v')
    ..addFlag(
      'local',
      defaultsTo: true,
      help: 'Replace $repository by this checkout',
    );
  var results = parser.parse(args);
  if (results['help'] as bool || results.rest.length != 1) {
    stdout.writeln('Usage: dart run tool/act_run.dart [options] <workflow>\n');
    stdout.writeln(parser.usage);
    exit(results.rest.length != 1 ? 1 : 0);
  }

  // repo_support/tool is run from repo_support, the repository is the parent.
  var root = normalize(absolute('..'));
  var workflow = findWorkflow(root, results.rest.first);
  var act = await findAct();
  var options = <String>[
    'workflow_dispatch',
    '-W',
    join('.github', 'workflows', workflow),
    '-P',
    'ubuntu-latest=$image',
    '--pull=${await imageMissing()}',
    '--cache-server-path',
    join(root, '.dart_tool', 'act_cache'),
    if (results['local'] as bool) ...[
      '--local-repository',
      '$repository=$root',
    ],
    if (results['dry-run'] as bool) '-n',
    if (results['job'] != null) ...['-j', results['job'] as String],
    for (var input in results['input'] as List<String>) ...['--input', input],
  ];
  try {
    await Shell(workingDirectory: root).run('$act ${shellArguments(options)}');
  } on ShellException catch (e) {
    stderr.writeln('act failed: ${e.message}');
    exit(1);
  }
}

/// `act` from the path, or the gh extension.
Future<String> findAct() async {
  if (whichSync('act') != null) {
    return 'act';
  }
  var extensions = await Shell(verbose: false).run('gh extension list');
  if (extensions.outText.contains('nektos/gh-act')) {
    return 'gh act';
  }
  stderr.writeln(
    'act not found: `gh extension install nektos/gh-act` or install act',
  );
  exit(1);
}

/// Exact file name, `<name>.yml` or the unique file ending with `<name>.yml`.
String findWorkflow(String root, String name) {
  var files =
      Directory(join(root, '.github', 'workflows'))
          .listSync()
          .whereType<File>()
          .map((file) => basename(file.path))
          .where((file) => file.endsWith('.yml'))
          .toList()
        ..sort();
  var found = files.where((file) => file == name || file == '$name.yml');
  if (found.isEmpty) {
    found = files.where((file) => file.endsWith('_$name.yml'));
  }
  if (found.length != 1) {
    stderr.writeln(
      '${found.isEmpty ? 'No' : 'Several'} workflows matching $name:\n'
      '  ${(found.isEmpty ? files : found).join('\n  ')}',
    );
    exit(1);
  }
  return found.first;
}

/// True if the act image is not pulled yet.
Future<bool> imageMissing() async {
  try {
    await Shell(verbose: false).run('docker image inspect $image');
    return false;
  } on ShellException {
    return true;
  }
}
```

## 6. Rollout

1. Add `smoke.yml`, remove `push:` from the 22 other workflows, drop the
   legacy ones of section 1. Move `v1` (nothing consumer facing changes, the
   triggers are per repository).
2. `repo_support/tool/gh_workflow_run.dart` (section 2.3), used from then
   on for every change in `.github`.
   With `--local` (section 5.5) once act is installed: run locally first,
   dispatch second.
3. Local twins for the leaf actions (section 3, step 1), fix the two known
   action bugs, move `v1`.
4. `ci_test/flutter_app` (section 4, A).
5. Templates folder + lint (templates document), update README to point to
   it.
6. Tool moved to `tekartik_ci` with the `--ci-ref` mode, public test
   repository (section 4, B).

## Open questions

- Keep the weekly schedule on all supported workflows or only on the `*_all`
  and `*_analyze` ones?
- `run-name` label input on every workflow (exact run lookup) or the time
  window heuristic? The label costs one line per workflow file.
- The flutter analyze jobs run `pub get` + `pub downgrade`; the old action
  ran `pub downgrade` + `pub upgrade`. Without a committed `pubspec.lock` the
  two are the same; with one, `pub upgrade` is the honest "latest" leg.
- Private git dependencies: the reusable workflows have no hook to configure
  git credentials before pub get. A `secrets: git-token` on `workflow_call`
  running `git config --global url."https://x-access-token:$TOKEN@github.com/".insteadOf "https://github.com/"`
  would cover it (section 4, C is where to test it).
