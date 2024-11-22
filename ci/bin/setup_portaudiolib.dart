import 'package:tekartik_ci/setup_ci_github.dart';

Future<void> main() async {
  /// Linux only, no op on other platforms
  await sudoSetupPortaudioLib();
}
