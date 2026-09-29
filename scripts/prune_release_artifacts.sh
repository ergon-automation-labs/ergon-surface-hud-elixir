#!/usr/bin/env bash
#
# Prune this repo's own release artifacts.
#
# WHY THIS EXISTS
# ---------------
# `mix release --overwrite` does not clear the release directory. Every build
# leaves its app copy behind:
#
#   _build/prod/rel/<rel>/lib/<app>-0.2.46
#   _build/prod/rel/<rel>/lib/<app>-0.2.47     ... one per version, forever
#   _build/prod/rel/<rel>/releases/0.2.46/
#   _build/prod/rel/<rel>/releases/0.2.47/
#
# and the tarball is built from that whole directory, so a release published
# today ships every past copy of the app. Measured 2026-09-29: the dashboard's
# 0.2.47 tarball carried 65 copies of the app (2194 files under lib/), and 64
# tarballs — 1.1 GB — had piled up at the repo root.
#
# So the two halves run at the two moments that matter:
#
#   * --build-tree, BEFORE `mix release`  → the artifact ships one app copy
#   * --archives,   AFTER a verified publish → GitHub holds the asset now
#
# The archive half covers TWO piles, because this repo grows both:
#   * <repo>/<app>-<ver>.tar.gz        — what the pre-push hook tars for GitHub
#   * <repo>/_build/prod/<app>-<ver>.tar.gz — what `mix release` writes itself
#     when mix.exs declares `steps: [:assemble, :tar]` (the dashboard's does;
#     measured: 64 tarballs, 710 MB, inside _build/prod)
#
# WHAT IT WILL NEVER TOUCH
# ------------------------
#   * published GitHub releases (this script never calls `gh`)
#   * the current version, or the newest --keep-build / --keep-archives ones
#   * anything tracked by git, and anything outside _build/ or this repo root
#
# USAGE
#   scripts/prune_release_artifacts.sh                       # dry run, both halves
#   scripts/prune_release_artifacts.sh --build-tree --apply  # before `mix release`
#   scripts/prune_release_artifacts.sh --archives  --apply   # after a verified publish
#
#   --apply                actually delete (default: print the plan and stop)
#   --build-tree           prune _build/prod/rel only
#   --archives             prune root tarballs only
#   --keep-build N         versions kept in the build tree (default 1)
#   --keep-archives N      tarballs kept per pile (default 3): the repo root
#                          and _build/prod are pruned separately
#   --rel NAME             release directory under _build/prod/rel (default: the
#                          only one there; pass it if the tree holds several)
#   --repo DIR             repo root (default: the script's parent directory)
#
# Exit status: 0 whether or not anything was pruned. Non-zero only when the
# invocation itself is wrong (bad flag, unreadable mix.exs, ambiguous tree) —
# so a caller can safely run this as housekeeping without it becoming a gate.

set -euo pipefail

APPLY=0
DO_BUILD=0
DO_ARCHIVES=0
KEEP_BUILD=1
KEEP_ARCHIVES=3
REL_NAME=""
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  sed -n '/^# USAGE/,/^# Exit status/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

die() {
  echo "prune-release-artifacts: $*" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --build-tree) DO_BUILD=1 ;;
    --archives) DO_ARCHIVES=1 ;;
    --keep-build) KEEP_BUILD="${2:-}"; shift ;;
    --keep-archives) KEEP_ARCHIVES="${2:-}"; shift ;;
    --rel) REL_NAME="${2:-}"; shift ;;
    --repo) REPO="${2:-}"; shift ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown flag: $1 (try --help)" ;;
  esac
  shift
done

echo "$KEEP_BUILD" | grep -qE '^[0-9]+$' || die "--keep-build wants a number, got '$KEEP_BUILD'"
echo "$KEEP_ARCHIVES" | grep -qE '^[0-9]+$' || die "--keep-archives wants a number, got '$KEEP_ARCHIVES'"

if [ "$DO_BUILD" -eq 0 ] && [ "$DO_ARCHIVES" -eq 0 ]; then
  DO_BUILD=1
  DO_ARCHIVES=1
fi

[ -d "$REPO" ] || die "no such directory: $REPO"
cd "$REPO"

APP="$(grep -oE 'app:[[:space:]]*:[a-z0-9_]+' mix.exs 2>/dev/null | head -1 | sed 's/.*://')"
[ -n "$APP" ] || die "could not read 'app:' from $REPO/mix.exs"

# A tarball is not always named after the app. `global_surface_liveview`'s app
# is `global_surface`, but every tarball it publishes is
# `global_surface_liveview-*.tar.gz` — the release directory's name. Matching on
# the app name alone left 31 tarballs (half a gigabyte) on that repo's disk
# while reporting success. Both names are this repo's artifacts, so both count.
# Best effort here: the build tree may not exist yet, and the build-tree section
# below resolves the same thing strictly when it needs to act.
REL_NAME_GUESS=""
for d in "$REPO"/_build/prod/rel/*/; do
  [ -d "${d}releases" ] || continue
  ls "${d}lib/$APP"-[0-9]* >/dev/null 2>&1 || continue
  REL_NAME_GUESS="$(basename "${d%/}")"
  break
done

# Version strings only, and only this app's. Deps in lib/ (asn1-5.3.4.2,
# phoenix-1.7.23) and non-version entries (COOKIE, start_erl.data) never match.
VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+$'

sort_versions_desc() {
  # Newest first, numerically.
  #
  # NOT `sort -t. -k1,1n -k2,2n -k3,3n -r`: measured on macOS 2.3-Apple (199),
  # a global -r is IGNORED when the keys carry per-key n modifiers, so that line
  # sorts ASCENDING and hands back the oldest version as "newest" — which is how
  # a prune script deletes the version it was supposed to keep. Plain awk cannot
  # get this wrong.
  awk -F. '
    { v[NR] = $0; k[NR] = $1 * 1000000 + $2 * 1000 + $3 }
    END {
      for (i = 1; i <= NR; i++)
        for (j = i + 1; j <= NR; j++)
          if (k[j] > k[i]) {
            t = k[i]; k[i] = k[j]; k[j] = t
            s = v[i]; v[i] = v[j]; v[j] = s
          }
      for (i = 1; i <= NR; i++) print v[i]
    }'
}

# Prints the versions to KEEP: the newest N of those given, plus `current`
# (the version already built, or the newest archive) even if it is older.
kept_versions() {
  local keep="$1" current="$2"
  shift 2
  {
    [ -n "$current" ] && echo "$current"
    printf '%s\n' "$@" | sort_versions_desc | head -n "$keep"
  } | grep -vE '^$' | sort -u
}

kb_of() {
  # Size of one path in KiB; a missing path is 0, not an error.
  if [ -e "$1" ]; then
    du -sk "$1" 2>/dev/null | awk '{print $1}'
  else
    echo 0
  fi
}

bytes_of_file() {
  if [ -e "$1" ]; then
    wc -c <"$1" | tr -d ' '
  else
    echo 0
  fi
}

human_kb() {
  awk -v kb="$1" 'BEGIN {
    if (kb >= 1048576) printf "%.1f GB", kb / 1048576;
    else if (kb >= 1024) printf "%.1f MB", kb / 1024;
    else printf "%d KB", kb;
  }'
}

dir_label() {
  case "$1" in
    "$REPO") echo "the repo root" ;;
    *) echo "${1#"$REPO"/}" ;;
  esac
}

# List what would go, delete it if asked, and report both. Every path to be
# removed must sit inside $REPO and match the strict version shape above.
# A build artifact that git TRACKS is not ours to delete: removing it would be
# a commit, not a cleanup (ergon_surface_hud_elixir tracks 28 release tarballs,
# so the first sweep deleted two version-controlled files). Refuse those and say
# so — a silent skip would look like the file did not match.
tracked_by_git() { # tracked_by_git <path>
  command -v git >/dev/null 2>&1 || return 1
  git -C "$REPO" ls-files --error-unmatch -- "$1" >/dev/null 2>&1
}

tracked_skip_note() { # tracked_skip_note <path>
  echo "    ⚠️  keeping ${1#"$REPO"/} — git tracks it, so removing it would be a commit"
}

prune_paths() {
  local label="$1" freed_kb="$2" shown=0 total="$3"
  shift 3
  if [ "$APPLY" -eq 1 ]; then
    local p
    for p in "$@"; do
      case "$p" in "$REPO"/*) rm -rf -- "$p" ;; *) die "refusing to delete outside the repo: $p" ;; esac
    done
  fi
  local n=0
  for p in "$@"; do
    n=$((n + 1))
    if [ "$APPLY" -eq 1 ] || [ "$n" -le 5 ]; then
      echo "    - ${p#"$REPO"/}"
      shown=$((shown + 1))
    fi
  done
  if [ "$APPLY" -eq 0 ] && [ "$n" -gt "$shown" ]; then
    echo "    ... and $((n - shown)) more"
  fi
  printf '  %s: %s %s (%s)\n' "$label" \
    "$([ "$APPLY" -eq 1 ] && echo removed || echo to remove)" \
    "$total" "$(human_kb "$freed_kb")"
}

# ── the build tree ──────────────────────────────────────────────────────────
if [ "$DO_BUILD" -eq 1 ]; then
  REL_DIRS=()
  for d in "$REPO"/_build/prod/rel/*/; do
    [ -d "${d}releases" ] && REL_DIRS+=("${d%/}")
  done

  if [ "${#REL_DIRS[@]}" -eq 0 ]; then
    # Never built here yet — say so rather than staying quiet, so a reader of
    # the hook log can tell "nothing to prune" from "the prune did not run".
    echo "🧹 build tree: no release directory under _build/prod/rel yet — nothing to prune"
  else
    if [ -n "$REL_NAME" ]; then
      REL="$REPO/_build/prod/rel/$REL_NAME"
      [ -d "$REL/releases" ] || die "--rel $REL_NAME is not a release directory under _build/prod/rel"
    elif [ "${#REL_DIRS[@]}" -eq 1 ]; then
      REL="${REL_DIRS[0]}"
    else
      # One _build can hold more than one app's release: a repo that also
      # builds a sibling surface, or one that was seeded from another repo's
      # tree. Pick the directory that actually holds THIS app's code instead of
      # refusing to work at all — refusing was correct while the choice was
      # ambiguous, but the app name resolves it.
      OURS=()
      for d in "${REL_DIRS[@]}"; do
        ls "$d"/lib/"$APP"-[0-9]* >/dev/null 2>&1 && OURS+=("$d")
      done
      if [ "${#OURS[@]}" -eq 1 ]; then
        REL="${OURS[0]}"
      else
        die "release directory for $APP is ambiguous under _build/prod/rel (candidates: ${REL_DIRS[*]}) — pass --rel NAME"
      fi
    fi

    CURRENT=""
    if [ -f "$REL/releases/start_erl.data" ]; then
      CURRENT="$(awk '{print $2}' "$REL/releases/start_erl.data")"
    fi
    echo "$CURRENT" | grep -qE "$VERSION_RE" || CURRENT=""

    VERS=()
    for p in "$REL"/lib/"$APP"-[0-9]*.[0-9]*.[0-9]* "$REL"/releases/[0-9]*.[0-9]*.[0-9]*; do
      [ -d "$p" ] || continue
      v="$(basename "$p")"
      case "$v" in "$APP"-*) v="${v#"$APP"-}" ;; esac
      echo "$v" | grep -qE "$VERSION_RE" || continue
      VERS+=("$v")
    done

    KEEP_LIST=""
    [ "${#VERS[@]}" -gt 0 ] && KEEP_LIST="$(kept_versions "$KEEP_BUILD" "$CURRENT" "${VERS[@]}")"

    DOOMED=()
    DOOMED_KB=0

    for p in "$REL"/lib/"$APP"-[0-9]*.[0-9]*.[0-9]*; do
      [ -d "$p" ] || continue
      v="$(basename "$p" | sed "s/^$APP-//")"
      echo "$v" | grep -qE "$VERSION_RE" || continue
      echo "$KEEP_LIST" | grep -qx "$v" && continue
      if tracked_by_git "$p"; then tracked_skip_note "$p"; continue; fi
      DOOMED+=("$p")
      DOOMED_KB=$((DOOMED_KB + $(kb_of "$p")))
    done

    for p in "$REL"/releases/[0-9]*.[0-9]*.[0-9]*; do
      [ -d "$p" ] || continue
      v="$(basename "$p")"
      echo "$v" | grep -qE "$VERSION_RE" || continue
      echo "$KEEP_LIST" | grep -qx "$v" && continue
      if tracked_by_git "$p"; then tracked_skip_note "$p"; continue; fi
      DOOMED+=("$p")
      DOOMED_KB=$((DOOMED_KB + $(kb_of "$p")))
    done

    echo "🧹 build tree $REL (release $APP, built $([ -n "$CURRENT" ] && echo "$CURRENT" || echo 'never'))"
    echo "    keeping: $(echo "$KEEP_LIST" | tr '\n' ' ')"
    if [ "${#DOOMED[@]}" -eq 0 ]; then
      echo "  nothing to remove"
    else
      prune_paths "build tree" "$DOOMED_KB" "${#DOOMED[@]} entries" "${DOOMED[@]}"
    fi
  fi
fi

# ── the archives ────────────────────────────────────────────────────────────
ARCHIVE_NAMES=("$APP")
for n in "$REL_NAME_GUESS" "${REL_NAME:-}"; do
  [ -n "$n" ] || continue
  printf '%s\n' "${ARCHIVE_NAMES[@]}" | grep -qx "$n" && continue
  ARCHIVE_NAMES+=("$n")
done
archive_name_label() { printf '%s' "${ARCHIVE_NAMES[*]}"; }

# The version in a tarball's name, or nothing if the name is not one of this
# repo's artifacts (a sibling surface's tarball, a hand-made test tarball).
archive_version() { # archive_version <basename>
  local b="$1" n v
  for n in "${ARCHIVE_NAMES[@]}"; do
    case "$b" in
      "$n"-[0-9]*.[0-9]*.[0-9]*.tar.gz)
        v="${b#"$n"-}"
        v="${v%.tar.gz}"
        echo "$v" | grep -qE "$VERSION_RE" && { echo "$v"; return 0; }
        ;;
    esac
  done
  return 1
}

# One pile of tarballs for this app in one directory: keep the newest
# --keep-archives, remove the rest. Safe to call on a directory that has none.
prune_archives_in() {
  local dir="$1"
  [ -d "$dir" ] || return 0

  local -a versions=()
  local -a doomed=()
  local f v doomed_kb keep_arch newest

  for f in "$dir"/*.tar.gz; do
    [ -f "$f" ] || continue
    v="$(archive_version "$(basename "$f")")" || continue
    versions+=("$v")
  done

  if [ "${#versions[@]}" -eq 0 ]; then
    echo "🧹 archives in $(dir_label "$dir"): none for $(archive_name_label)"
    return 0
  fi

  newest="$(printf '%s\n' "${versions[@]}" | sort_versions_desc | head -1)"
  keep_arch="$(kept_versions "$KEEP_ARCHIVES" "$newest" "${versions[@]}")"

  doomed_kb=0
  for f in "$dir"/*.tar.gz; do
    [ -f "$f" ] || continue
    v="$(archive_version "$(basename "$f")")" || continue
    echo "$keep_arch" | grep -qx "$v" && continue
    if tracked_by_git "$f"; then tracked_skip_note "$f"; continue; fi
    doomed+=("$f")
    doomed_kb=$((doomed_kb + ($(bytes_of_file "$f") + 1023) / 1024))
  done

  echo "🧹 archives in $(dir_label "$dir") (${#versions[@]} for $(archive_name_label))"
  echo "    keeping: $(echo "$keep_arch" | tr '\n' ' ')"
  if [ "${#doomed[@]}" -eq 0 ]; then
    echo "  nothing to remove"
  else
    prune_paths "archives" "$doomed_kb" "${#doomed[@]} tarballs" "${doomed[@]}"
  fi
}

if [ "$DO_ARCHIVES" -eq 1 ]; then
  prune_archives_in "$REPO"
  prune_archives_in "$REPO/_build/prod"
fi

if [ "$APPLY" -eq 0 ]; then
  echo ""
  echo "Dry run — nothing was deleted. Add --apply to act."
fi
