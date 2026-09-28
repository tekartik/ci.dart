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
