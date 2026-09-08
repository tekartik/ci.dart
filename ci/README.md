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
      - name: Install libsqlite3
        run: |
          dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
          dart pub global run tekartik_ci:setup_sqlite3lib
```


## Portaudio

If you ever encounter
```
Failed to load dynamic library 'libportaudio.so'
```

you can include the following steps in your github actions workflow:

```yaml
jobs:
  build:
    steps:
      - name: Install libportaudio
        run: |
          dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
          dart pub global run tekartik_ci:setup_portaudiolib
```
## Alsa

If you ever encounter
```
Failed to load dynamic library 'libasound.so'
```

you can include the following steps in your github actions workflow:

```yaml
jobs:
  build:
    steps:
      - name: Install libasound2
        run: |
          dart pub global activate --source git https://github.com/tekartik/ci.dart --git-path ci
          dart pub global run tekartik_ci:setup_alsalib
```

This is needed for [flutter_soloud](https://docs.page/alnitak/flutter_soloud_docs/get_started/setup#linux-setup) and [flutter_sound](https://pub.dev/packages/flutter_sound#linux-setup) packages.