import 'package:process_run/shell_run.dart';
import 'package:tekartik_ci/ci_flutter.dart';
import 'package:tekartik_common_utils/json_utils.dart';

Future main() async {
  print('Environment variables:');
  print(jsonPretty(shellEnvironment));
  await run('flutter --version');

  await setup();

  /*flutter channel stable
      - flutter upgrade

   */
}
