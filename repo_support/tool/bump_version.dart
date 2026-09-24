import 'package:tekartik_common_build/version_io.dart';

Future<void> main() async {
  await pathAppVersionBumpAndGenerate(patch: true);
}
