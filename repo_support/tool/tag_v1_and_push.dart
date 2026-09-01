import 'package:dev_build/shell.dart';

Future<void> main(List<String> args) async {
  var shell = Shell();
  await shell.run('''
git fetch origin --tags --force
git tag -fa v1 -m "Update v1 to latest stable changes"
git push origin master --follow-tags --force
git push origin v1 --force
  ''');
}
