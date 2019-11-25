import 'package:process_run/shell.dart';

Future dartTest(Shell shell) async {
  await shell.run('''
  
  pub get
  pub run test
  
      ''');
}

Future flutterTest(Shell shell) async {
  await shell.run('''
  
  flutter analyze
  flutter test
  
      ''');
}
