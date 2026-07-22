#!/usr/bin/env sh

dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
dart pub global run tekartik_ci:setup_sqlite3lib