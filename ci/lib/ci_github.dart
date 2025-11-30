import 'package:tekartik_platform_io/util/github_util.dart';

/// Whether running in Github Actions CI
bool get runningInGithubActions => platformIo.runningOnGithub;
