#!/usr/bin/env bash
# SNPanel bootstrap installer.
#
#   curl -fsSL https://raw.githubusercontent.com/vnscorpion/snpanel-releases/main/install.sh | bash
#
# Downloads a release bundle from https://github.com/vnscorpion/snpanel-releases
# (the newest stable release, or SNPANEL_VERSION), checks it against the
# SHA256SUMS published with it, unpacks it and runs the installer it carries.
# Nothing in the bundle is unpacked, let alone run, before the check.
#
# On a server that already runs SNPanel (/opt/snpanel/backend/.env exists) it
# updates it to that release with the bundle's own updater instead: that is
# how a server installed before v2.0.0, whose updater still looks for
# releases in the panel's private source repository, moves to this channel.
#
# Environment:
#   SNPANEL_VERSION=v2.0.0       install (or update to) this release; a
#                                prerelease such as v2.0.0-rc.1 too
#   PANEL_URL=https://host:2222  answers the hostname/port questions, so the
#                                install runs without a terminal
#   SNPANEL_RELEASE_REPO         another release repository (development)
#   SNPANEL_KEEP_BUNDLE=yes      keep the unpacked bundle afterwards
# Every other setting the installer reads (PANEL_PORT, ENABLE_SSL, SSL_EMAIL,
# PHP_VERSIONS, SNPANEL_RESOURCE_LIMITS ...) is passed through to it.
#
# Everything is inside main(), so bash has read the whole script before the
# first command runs: with `curl | bash` the script arrives on stdin, and a
# command reading stdin would otherwise eat the rest of it.

set -euo pipefail

# --- BEGIN installer/lib/release-channel.sh (kept identical by a test) ---
# shellcheck shell=bash
# The release channel: where SNPanel releases come from and how one is fetched.
#
# Releases are published to a public repository of their own,
# github.com/vnscorpion/snpanel-releases. It holds the bootstrap install.sh,
# the release notes and, as assets of each GitHub release, two files:
#
#   snpanel-<tag>-x86_64-linux.tar.gz   the release bundle
#   SHA256SUMS                          its checksum
#
# The bundle is everything an install or an update needs at run time - the
# installer, the prebuilt frontend, the webmail and the five static Rust
# binaries in bin/ - and no source. The panel's source repository is private,
# so nothing here may depend on reading it.
#
# Sourced, not executed, by install.sh, update.sh and lib/rust-binaries.sh;
# the bootstrap install.sh at the root of the release repository carries the
# same text between its BEGIN/END markers (a test keeps the two identical).
# Every function reports through stderr and its return code, and never exits:
# the caller decides what a failure means.
#
# Overrides, for the owner's development use:
#   SNPANEL_RELEASE_REPO   another GitHub repository with the same layout
#                          (default https://github.com/vnscorpion/snpanel-releases)
#   SNPANEL_VERSION        a tag to use instead of the newest stable release,
#                          a prerelease included (v2.0.0-rc.1)

SNPANEL_DEFAULT_RELEASE_REPO="https://github.com/vnscorpion/snpanel-releases"
SNPANEL_RELEASE_ARCH="x86_64-linux"

# The repository releases come from, as https://github.com/<owner>/<name>.
release_repo_url() {
  local repo="${SNPANEL_RELEASE_REPO:-$SNPANEL_DEFAULT_RELEASE_REPO}"
  repo="${repo%/}"
  repo="${repo%.git}"
  printf '%s\n' "$repo"
}

# <owner>/<name> of the release repository; fails for anything that is not a
# github.com repository, because the latest-release lookup is GitHub's API.
release_repo_slug() {
  local repo slug
  repo="$(release_repo_url)"
  case "$repo" in
    https://github.com/*) slug="${repo#https://github.com/}" ;;
    *)
      echo "SNPANEL_RELEASE_REPO must be a https://github.com/<owner>/<name> repository (got: ${repo})" >&2
      return 1
      ;;
  esac
  if [[ ! "$slug" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "SNPANEL_RELEASE_REPO is not a repository address: ${repo}" >&2
    return 1
  fi
  printf '%s\n' "$slug"
}

# A release tag: v<major>.<minor>.<patch>, optionally -<prerelease> such as
# -rc.1. Checked before a tag is put into a URL or a path.
release_tag_valid() {
  [[ "${1:-}" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]
}

# A stable release tag: no prerelease part.
release_tag_stable() {
  [[ "${1:-}" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

# The newest stable release: GitHub's releases/latest (which never names a
# prerelease or a draft), else the repository's tags over git, else the
# address github.com redirects releases/latest to.
release_latest_tag() {
  local slug repo tag=""
  slug="$(release_repo_slug)" || return 1
  repo="$(release_repo_url)"

  tag="$(curl -fsSL --connect-timeout 10 --max-time 30 \
          -H 'Accept: application/vnd.github+json' \
          "https://api.github.com/repos/${slug}/releases/latest" 2>/dev/null \
        | sed -n 's/^[[:space:]]*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | head -n 1)" || true
  if release_tag_stable "$tag"; then
    printf '%s\n' "$tag"
    return 0
  fi

  # The API allows 60 unauthenticated requests an hour per address, which a
  # busy NAT can use up. Tags over git have no such limit.
  if command -v git >/dev/null 2>&1; then
    tag="$(GIT_TERMINAL_PROMPT=0 timeout 60 git ls-remote --tags --refs "${repo}.git" 'refs/tags/v*' 2>/dev/null \
          | awk '{ sub("refs/tags/", "", $2); print $2 }' \
          | grep -E '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' \
          | sort -V | tail -n 1)" || true
    if release_tag_stable "$tag"; then
      printf '%s\n' "$tag"
      return 0
    fi
  fi

  tag="$(curl -fsI --connect-timeout 10 --max-time 30 "${repo}/releases/latest" 2>/dev/null \
        | tr -d '\r' \
        | sed -n 's#^[Ll]ocation:.*/releases/tag/\([^/[:space:]]*\)$#\1#p' \
        | head -n 1)" || true
  if release_tag_stable "$tag"; then
    printf '%s\n' "$tag"
    return 0
  fi

  echo "No stable SNPanel release found at ${repo}" >&2
  return 1
}

# The bundle's file name for a tag.
release_bundle_name() {
  printf 'snpanel-%s-%s.tar.gz\n' "$1" "$SNPANEL_RELEASE_ARCH"
}

# release_fetch_bundle <tag> <work dir>
#
# Downloads the bundle and SHA256SUMS of <tag> into <work dir>, checks the
# bundle against its published SHA-256 - nothing of it is unpacked, let alone
# run, before that - and unpacks it there. Prints the bundle's root
# directory. The work dir is the caller's to remove.
release_fetch_bundle() {
  local tag="$1" work="$2" repo name base expected actual root
  if ! release_tag_valid "$tag"; then
    echo "Not a release tag: ${tag:-<empty>} (expected vX.Y.Z or vX.Y.Z-rc.N)" >&2
    return 1
  fi
  [[ -d "$work" ]] || { echo "No work directory: ${work}" >&2; return 1; }
  repo="$(release_repo_url)"
  release_repo_slug >/dev/null || return 1
  name="$(release_bundle_name "$tag")"
  base="${repo}/releases/download/${tag}"

  echo "Downloading ${base}/${name}" >&2
  if ! curl -fL --connect-timeout 10 --max-time 900 --retry 3 --retry-delay 3 \
        -sS -o "${work}/${name}" "${base}/${name}"; then
    echo "Could not download ${name} for ${tag} from ${repo} (is ${tag} published there?)" >&2
    return 1
  fi
  if ! curl -fL --connect-timeout 10 --max-time 60 --retry 3 --retry-delay 3 \
        -sS -o "${work}/SHA256SUMS" "${base}/SHA256SUMS"; then
    echo "Release ${tag} has no SHA256SUMS; refusing to use its bundle" >&2
    return 1
  fi

  expected="$(awk -v f="$name" '$2 == f || $2 == ("*" f) { print $1; exit }' "${work}/SHA256SUMS")"
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ ]]; then
    echo "SHA256SUMS of ${tag} lists no checksum for ${name}; refusing to use it" >&2
    return 1
  fi
  actual="$(sha256sum "${work}/${name}" | awk '{ print $1 }')"
  if [[ "$actual" != "$expected" ]]; then
    echo "${name} does not match its published SHA-256 (expected ${expected}, got ${actual}); refusing to use it" >&2
    return 1
  fi
  echo "SHA-256 verified: ${name}" >&2

  if ! tar -xzf "${work}/${name}" -C "$work" --no-same-owner; then
    echo "Could not unpack ${name}" >&2
    return 1
  fi
  root="${work}/snpanel-${tag}"
  if [[ ! -f "${root}/installer/install.sh" || ! -f "${root}/VERSION" || ! -d "${root}/bin" ]]; then
    echo "${name} is not an SNPanel release bundle (no snpanel-${tag}/installer, VERSION or bin)" >&2
    return 1
  fi
  printf '%s\n' "$root"
}
# --- END installer/lib/release-channel.sh ---

bootstrap_die() {
  echo "ERROR: $*" >&2
  exit 1
}

bootstrap_need_tools() {
  local missing=() tool
  for tool in curl tar gzip sha256sum awk sed; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  (( ${#missing[@]} == 0 )) && return 0
  # A minimal image can lack tar or gzip; both come with the base system
  # everywhere SNPanel installs, under these names.
  echo "==> Installing what the bootstrap needs: ${missing[*]}"
  if command -v dnf >/dev/null 2>&1; then
    dnf -y install curl tar gzip coreutils gawk sed >/dev/null
  elif command -v apt-get >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get update -qq >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl tar gzip coreutils gawk sed >/dev/null
  else
    bootstrap_die "missing ${missing[*]}, and no dnf or apt-get to install them with"
  fi
}

main() {
  [[ $EUID -eq 0 ]] || bootstrap_die "run this as root"
  [[ "$(uname -m)" == "x86_64" ]] || bootstrap_die "SNPanel releases are built for x86_64; this machine is $(uname -m)"
  bootstrap_need_tools

  local tag work root app_dir status=0
  if [[ -n "${SNPANEL_VERSION:-}" ]]; then
    tag="$SNPANEL_VERSION"
    release_tag_valid "$tag" || bootstrap_die "SNPANEL_VERSION=${tag} is not a release tag (vX.Y.Z or vX.Y.Z-rc.N)"
  else
    echo "==> Looking up the newest SNPanel release at $(release_repo_url)"
    tag="$(release_latest_tag)" || bootstrap_die "could not find a release; set SNPANEL_VERSION=vX.Y.Z to choose one"
  fi
  echo "==> SNPanel ${tag}"

  work="$(mktemp -d /var/tmp/snpanel-release.XXXXXX)"
  if [[ "${SNPANEL_KEEP_BUNDLE:-no}" != "yes" ]]; then
    # shellcheck disable=SC2064
    trap "cd /; rm -rf -- '${work}'" EXIT
  fi
  root="$(release_fetch_bundle "$tag" "$work")" || bootstrap_die "could not get release ${tag}"
  # Readable by the accounts the installer switches to while it runs.
  chmod 0755 "$work"

  app_dir="${APP_DIR:-/opt/snpanel}"
  if [[ -f "${app_dir}/backend/.env" ]]; then
    echo "==> SNPanel is already installed in ${app_dir}: updating it to ${tag}"
    SOURCE_DIR="$root" SNPANEL_UPDATE_REF_OVERRIDE="$tag" \
      bash "${root}/installer/update.sh" --skip-pull </dev/null || status=$?
  elif (exec </dev/tty) 2>/dev/null; then
    bash "${root}/installer/install.sh" </dev/tty || status=$?
  else
    # No terminal: the installer asks nothing when PANEL_URL is set, and says
    # so when it is not.
    bash "${root}/installer/install.sh" </dev/null || status=$?
  fi
  if [[ "${SNPANEL_KEEP_BUNDLE:-no}" == "yes" ]]; then
    echo "==> The release bundle is kept in ${root}"
  fi
  return "$status"
}

main "$@"
