import 'package:dev_test/package.dart';
import 'package:path/path.dart';

Future main() async {
  for (var dir in [
    'ci_support',
    'ci',
  ]) {
    await packageRunCi(join('..', dir));
  }
  await packageRunCi('.');
}