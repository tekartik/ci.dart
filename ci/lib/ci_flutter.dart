import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';
import 'package:pub_semver/pub_semver.dart';

/// Old setup
@Deprecated('To remove')
Future setup() async {
  if (shellEnvironment.containsKey('TEKARTIK_CI_CIRRUS')) {
    stdout.writeln('Cirrus flutter setup');
    await run('''
    flutter channel stable
    flutter upgrade
    ''');
  } else {
    stdout.writeln(
        'Use existing flutter installation ${await getFlutterBinVersion()} in ${await which('flutter')}');
  }
}

String _fixDirName(String dirName) => normalize(absolute(dirName));

/// Old generate
@Deprecated('To remove')
Future<bool> generate(
    {required String dirName, String? appName, bool? force}) async {
  force ??= false;
  appName ??= basename(dirName);
  var includeWeb = false;
  // ignore: parameter_assignments
  dirName = _fixDirName(dirName);
  final flutterVersion = (await getFlutterBinVersion())!;
  if (flutterVersion >= Version(1, 10, 1)) {
    includeWeb = true;
  }
  // var shell = Shell();
  if (!force) {
    stdout.writeln('Create $appName in $dirName. Continue Y/N?');

    final input = stdin.readLineSync()!;
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
  final shell = Shell(workingDirectory: dirname(dirName));
  if (includeWeb) {
    await shell.run('flutter config --enable-web');
    await shell
        .run('flutter create --platforms web --project-name $appName $dirName');
  } else {
    await shell.run('flutter create --project-name $appName $dirName');
  }

  stdout.writeln('created');
  return true;
}

/// Old flutter test
@Deprecated('To remove')
Future flutterTest(Shell shell) async {
  await shell.run('''
  
  dart format --set-exit-if-changed .
  flutter analyze --no-current-package .
  flutter test
 
      ''');
}
