# Flutter Docker image — web only

[![Build and push Docker images](https://github.com/PauloGrijp/docker-images-flutter-only-web/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/PauloGrijp/docker-images-flutter-only-web/actions/workflows/build-and-push.yml)

Docker image with the Flutter SDK and **only the web toolchain**, built for use as the
`container:` of a GitHub Actions job.

No Android SDK, no iOS toolchain, no desktop toolchain — so it is a fraction of the size of a
full Flutter image, pulls in seconds on CI, and does not depend on the wound-down
`cirruslabs/android-sdk` base image. If you need to build APKs, this is the wrong image.

```
ghcr.io/paulogrijp/flutter-web:3.44.8
```

Built for `linux/amd64` only, which is what every GitHub-hosted runner is.

## Using it in your project

Point a job's `container:` at the image and run Flutter directly — no `subosito/flutter-action`,
no SDK download, no cache warm-up:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/paulogrijp/flutter-web:3.44.8
    steps:
      - uses: actions/checkout@v6

      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test
      - run: flutter build web --release

      - uses: actions/upload-artifact@v4
        with:
          name: web-build
          path: build/web
```

Speed up repeat runs by caching the pub cache (the image sets `PUB_CACHE=/opt/pub-cache`):

```yaml
      - uses: actions/cache@v4
        with:
          path: /opt/pub-cache
          key: pub-${{ hashFiles('**/pubspec.lock') }}
          restore-keys: pub-
```

If the package is private, the job needs credentials:

```yaml
    container:
      image: ghcr.io/paulogrijp/flutter-web:3.44.8
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
```

Making the GHCR package public (see [`MAINTAINING.md`](./MAINTAINING.md)) removes that need.

Running it outside Actions works the same way:

```bash
docker run --rm -it -v "${PWD}:/build" ghcr.io/paulogrijp/flutter-web:3.44.8 \
    flutter build web --release
```

## Tags

| Tag      | Points at                       |
| -------- | ------------------------------- |
| `3.44.8` | exactly that Flutter release    |
| `3.44`   | the pinned release of that minor|
| `latest` | the currently pinned release    |

Pin the exact version (`3.44.8`) in a project you care about — `latest` and the minor alias move
whenever the pin in [`versions.json`](./versions.json) changes.

The published version does **not** follow Flutter stable automatically. It moves only when
someone edits `versions.json` or runs the **Bump Flutter version** workflow.

## What's in the image

- Debian 12 (bookworm-slim) + `ca-certificates`, `curl`, `git`, `unzip`, `xz-utils`, `zip`
- Flutter SDK at `/opt/flutter` (shallow clone of the release tag), Dart SDK on `PATH`
- `flutter precache --web` already run, so the web artifacts (including CanvasKit) ship in the image
- Android / iOS / desktop disabled in the Flutter config
- `PUB_CACHE=/opt/pub-cache`, `XDG_CONFIG_HOME=/opt/flutter-config` (stable even though Actions
  overrides `HOME` for container jobs), default workdir `/build`
- Telemetry disabled; the root-shell warning from the `flutter` wrapper is suppressed

Every build is smoke-tested before it is considered good: the workflow pulls the pushed image and
runs `flutter create` → `pub get` → `analyze` → `build web --release` inside it.

The image runs as `root`, which is the default for Actions container jobs.

## Origin

Forked from [`adrianjagielak/docker-images-flutter`](https://github.com/adrianjagielak/docker-images-flutter)
(itself a community continuation of `cirruslabs/docker-images-flutter`) and reduced to a
single-version, web-only, amd64-only image.

## Maintaining this repository

See [`MAINTAINING.md`](./MAINTAINING.md).
