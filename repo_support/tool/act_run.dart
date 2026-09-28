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
