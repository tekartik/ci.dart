import 'dart:io';

import 'package:dev_build/build_support.dart';
import 'package:dev_build/shell.dart';

/// Tag the current pubspec.yaml version, repoint v1 to it and push.
///
/// Bump the version in pubspec.yaml first, the tag must not exist yet.
Future<void> main(List<String> args) async {
  var version = pubspecYamlGetVersion(await pathGetPubspecYamlMap('.'));
  var tag = 'v$version';
  var shell = Shell();

  await shell.run('git fetch origin --tags --force');

  var existing = (await shell.run('git tag -l $tag')).outText.trim();
  if (existing.isNotEmpty) {
    stderr.writeln('Tag $tag already exists, bump version in pubspec.yaml');
    exit(1);
  }

  await shell.run('''
git tag -a $tag -m "Version $version"
git tag -fa v1 -m "Update v1 to $tag"
git push origin master --follow-tags --force
git push origin v1 --force
  ''');
}
