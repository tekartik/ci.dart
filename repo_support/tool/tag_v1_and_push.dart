import 'package:dev_build/shell.dart';

Future<void> main(List<String> args) async {
  var shell = Shell();
  await shell.run('''
git tag -fa v1 -m "Update v1 to latest stable changes"
git push origin master --follow-tags
  ''');
}
