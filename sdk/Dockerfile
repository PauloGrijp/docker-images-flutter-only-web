# Flutter SDK image for web builds only.
#
# Deliberately does NOT include the Android SDK, the iOS toolchain or any
# desktop toolchain: the image exists to run `flutter pub get`, `flutter
# analyze`, `flutter test` and `flutter build web` on CI. That keeps it a
# fraction of the size of a full Flutter image and removes the dependency on
# the wound-down cirruslabs/android-sdk base image.
FROM debian:bookworm-slim

ARG flutter_version

LABEL org.opencontainers.image.source=https://github.com/PauloGrijp/docker-images-flutter-only-web
LABEL org.opencontainers.image.description="Flutter SDK with the web toolchain only (no Android/iOS/desktop). For CI."
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.version=$flutter_version

ENV DEBIAN_FRONTEND=noninteractive

# git  -> required by the flutter tool itself and by git-sourced pub packages
# curl -> artifact downloads performed by the flutter tool
# openssh-client -> pub dependencies hosted in private git repos over SSH
# unzip/xz-utils/zip -> archive formats the flutter tool unpacks
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        openssh-client \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

ENV FLUTTER_HOME=/opt/flutter
ENV FLUTTER_ROOT=$FLUTTER_HOME \
    FLUTTER_VERSION=$flutter_version \
    PUB_CACHE=/opt/pub-cache

# GitHub Actions overrides HOME for container jobs (/github/home), which would
# otherwise hide the flutter settings written below. XDG_CONFIG_HOME is not
# overridden, so pin the settings there.
ENV XDG_CONFIG_HOME=/opt/flutter-config

ENV PATH=${PATH}:${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PUB_CACHE}/bin

# The flutter wrapper prints a superuser warning for a root shell. The wrapper
# stays quiet for Docker, for CI, and for a bot. Docker creates /.dockerenv, but
# containerd, Podman and a microVM sandbox do not. The image therefore creates
# the marker file and sets the bot flag.
ENV BOT=true
RUN touch /.dockerenv

RUN git clone --depth 1 --branch "${flutter_version}" https://github.com/flutter/flutter.git "${FLUTTER_HOME}"

# CI checks out the project with an arbitrary uid, and the flutter tool shells
# out to git inside both its own checkout and the project directory.
RUN git config --system --add safe.directory '*'

# The flag is --disable-analytics, not --disable-telemetry: the flutter tool
# still names the global flag after analytics even though its help text says
# telemetry (see FlutterGlobalOptions.kDisableAnalyticsFlag).
RUN flutter --disable-analytics \
    && flutter config \
        --enable-web \
        --no-enable-android \
        --no-enable-ios \
        --no-enable-linux-desktop \
        --no-enable-macos-desktop \
        --no-enable-windows-desktop \
    && flutter precache --web \
    && flutter doctor -v

# The container runs as root by default; keep the caches writable so a job that
# drops to another user can still run `flutter pub get`.
RUN chown -R root:root "${FLUTTER_HOME}" \
    && mkdir -p "${PUB_CACHE}" "${XDG_CONFIG_HOME}" \
    && chmod -R 0777 "${PUB_CACHE}" "${XDG_CONFIG_HOME}"

WORKDIR /build
