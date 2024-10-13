#!/usr/bin/env sh

dart pub global activate --source git git@github.com:tekartikprv/tools.dart.git --git-path ci --git-ref dart3a
dart pub global run tekartik_ci:setup_sqlite3lib