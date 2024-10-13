# Setup tools for ci

## Sqlite 3

If you ever encounter
```
Failed to load dynamic library 'libsqlite3.so'
```

you can include the following steps in your github actions workflow:

```yaml
jobs:
  build:
    steps:
      - name: Install libsqlite3-dev
        run: |
          dart pub global activate --source git git@github.com:tekartikprv/tools.dart.git --git-path ci --git-ref dart3a
          dart pub global run tekartik_ci:setup_sqlite3lib
```