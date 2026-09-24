# Maintaining this repository

This document is for whoever runs the build pipeline. Consumers of the published image only need
[`README.md`](./README.md).

## First-time setup

One-time steps for this repository (or a fork of it):

1. **Enable GitHub Actions** under the *Actions* tab if it is not on by default.
2. **Allow Actions to write to the repository.** Settings → Actions → General → *Workflow
   permissions* → "Read and write permissions". Required for **Bump Flutter version** to commit
   `versions.json` and dispatch the build.
3. **Run the build once.** Actions → **Build and push Docker images** → *Run workflow*. This is
   what creates the `flutter-web` package under your account on GHCR.
4. **Make the package public** (recommended): package page →
   `https://github.com/users/PauloGrijp/packages/container/package/flutter-web` → *Package
   settings* → *Change visibility* → *Public*. Until then, every consuming job must pass
   `credentials:` to pull it.
5. **Link the package to this repository** (also on the package settings page) so
   `GITHUB_TOKEN` from this repo keeps push access and the package shows up on the repo sidebar.

After forking, update the `org.opencontainers.image.source` label in
[`sdk/Dockerfile`](./sdk/Dockerfile) and the URLs in `README.md`. The registry path itself is
derived from `${{ github.repository_owner }}` (lowercased) at build time, so no workflow change is
needed for that.

## How the automation works

### `.github/workflows/build-and-push.yml`

Triggered by:

- pushes to `master` touching `versions.json`, `sdk/**`, or the workflow itself
- **Bump Flutter version** after it commits a new pin
- a weekly cron (Monday 05:00 UTC) so Debian security updates land even when Flutter does not move
- manual `workflow_dispatch`, with an optional `flutter_version` filter

For each entry in `versions.json` it builds one `linux/amd64` image, pushes it under the literal
version tag plus every alias, then **pulls it back from the registry and smoke-tests it** by
running `flutter create` → `pub get` → `analyze` → `build web --release` inside the container. A
broken image therefore fails the build instead of quietly becoming `latest`.

A per-Flutter-version `type=gha` cache scope keeps incremental builds fast without one version
invalidating another's cache.

There is no QEMU step: the image is amd64-only because it is meant to run on GitHub-hosted
runners. If an arm64 variant is ever needed, add `ubuntu-24.04-arm` to the matrix and merge the
two digests with a `docker buildx imagetools create` manifest job — do *not* reintroduce QEMU
emulation for the Flutter build, it is painfully slow.

### `.github/workflows/bump-flutter-version.yml`

Manual only. Takes a version (`3.44.8`) or a channel name (`stable`, `beta`), validates it against
Flutter's release index, rewrites `versions.json`, commits, and dispatches the build. Nothing in
this repository updates the Flutter version on its own.

Because pushes made by `GITHUB_TOKEN` do not trigger downstream workflows, the build is started
with an explicit `gh workflow run` call. That call waits until the API reports the pushed commit as
the branch tip before dispatching — `workflow_dispatch` resolves `--ref` to the tip *at dispatch
time*, so dispatching immediately can race the push and rebuild the previous version.

## Changing the Flutter version

Either:

```bash
bash scripts/set_flutter_version.sh 3.44.8   # or: stable / beta
git commit -am "chore: pin Flutter 3.44.8" && git push
```

or run **Bump Flutter version** from the Actions tab, which does the same thing on a runner.

The script refuses versions that are not in Flutter's published release index, so a typo fails
before the Docker build spends ten minutes on a `git clone --branch` that cannot succeed.

To publish more than one version at a time (e.g. keep `3.44.8` alongside a newer stable), add a
second object to the `images` array in `versions.json` by hand — the build matrix already supports
it; only the helper script is single-version.

## Local development

```bash
docker build --build-arg flutter_version=3.44.8 -t flutter-web:3.44.8 sdk

docker run --rm --workdir /tmp flutter-web:3.44.8 bash -c \
    'flutter create demo && cd demo && flutter build web --release'
```

On an Apple Silicon Mac add `--platform linux/amd64`; the build runs under emulation and is slow.

## Dependencies that may need attention over time

### `debian:bookworm-slim` (base image)

Debian 12 is supported until mid-2028 (LTS). Bump to the next stable (`trixie`) when convenient;
the only requirement is a glibc new enough for the prebuilt Dart SDK, plus the handful of packages
installed in the Dockerfile.

### Flutter's release index

`scripts/set_flutter_version.sh` reads
`https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json`. The JSON shape
it depends on:

- `.current_release.<channel>` → commit hash
- `.releases[] | select(.hash == <hash>) | .version` → version string
- `.releases[].version` → the set of valid pins

### Flutter tool flags used at build time

The Dockerfile calls `flutter --disable-telemetry`, `flutter config --no-enable-android …` and
`flutter precache --web`. Flutter occasionally renames these. Since the version is pinned, a rename
can only break the build when the pin moves — which is exactly when you will see it fail.

### Third-party GitHub Actions

`actions/checkout`, `docker/setup-buildx-action`, `docker/login-action` and
`docker/build-push-action` are pinned to major versions. Pin to commit SHAs if you want stricter
supply-chain guarantees.

## Maintenance checklist

Expect human attention when:

- **A Flutter bump breaks the build.** The smoke test will catch it; inspect the failing job, fix
  `sdk/Dockerfile`, push.
- **Debian's base tag goes EOL.** Bump the `FROM` line.
- **Flutter changes its release feed.** Update `scripts/set_flutter_version.sh`.
- **A consuming project needs a platform this image dropped.** That is a different image — do not
  add the Android SDK back here; publish a second Dockerfile instead.
