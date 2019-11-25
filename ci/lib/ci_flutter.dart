import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:process_run/shell_run.dart';
import 'package:process_run/src/flutterbin_cmd.dart';
import 'package:process_run/which.dart';
import 'package:pub_semver/pub_semver.dart';

Future setup() async {
  if (shellEnvironment.containsKey('TEKARTIK_CI_CIRRUS')) {
    print('Cirrus flutter setup');
    /*
    await run('''
    flutter channel stable
    flutter upgrade
    ''');

     */
  }
  print(
      'Use existing flutter installation ${await getFlutterVersion()} in ${await which('flutter')}');
}

String _fixDirName(String dirName) => normalize(absolute(dirName));

Future<bool> generate(
    {@required String dirName, String appName, bool force}) async {
  force ??= false;
  appName ??= basename(dirName);
  bool includeWeb = false;
  assert(dirName != null && appName != null,
      'invalid dir $dirName or app $appName');
  dirName = _fixDirName(dirName);
  var flutterVersion = await getFlutterVersion();
  if (flutterVersion >= Version(1, 10, 1)) {
    includeWeb = true;
  }
  // var shell = Shell();
  if (!force) {
    print('Create $appName in $dirName. Continue Y/N?');

    var input = stdin.readLineSync();
    if (input.toLowerCase() != 'y') {
      return false;
    }
  }
  try {
    await Directory(dirName).delete(recursive: true);
  } catch (_) {}
  try {
    await Directory(dirname(dirName)).create(recursive: true);
  } catch (_) {}
  var shell = Shell(workingDirectory: dirname(dirName));
  if (includeWeb) {
    await shell.run('flutter config --enable-web');
    await shell.run('flutter create --web --project-name $appName $dirName');
  } else {
    await shell.run('flutter create --project-name $appName $dirName');
  }

  print('created');
  return true;
}

Future flutterTest(Shell shell) async {
  await shell.run('''
  
  flutter format --set-exit-if-changed .
  flutter analyze --no-current-package .
  flutter test
 
      ''');
}
