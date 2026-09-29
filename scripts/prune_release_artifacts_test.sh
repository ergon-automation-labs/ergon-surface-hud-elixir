#!/bin/bash
# Tests for prune_release_artifacts.sh.
#
# The script deletes things inside a build tree, so the interesting behaviour is
# exactly the behaviour that is invisible in a passing run: what it KEEPS. Every
# test below builds a fake repo in a temp dir and asserts on what survived.
#
# The one that matters most is `build-tree after a version bump`: run the prune
# before the build and it keeps the version being replaced, the build adds the
# new one, and the artifact ships two copies of the app. The pre-push hook's
# assertion catches that, but only after failing a push — hence the test.
#
# Usage: scripts/prune_release_artifacts_test.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/prune_release_artifacts.sh"
APP="fake_surface"
FAILURES=0

check() { # check <label> <expected> <actual>
  if [ "$2" = "$3" ]; then
    printf '  ✓ %s\n' "$1"
  else
    printf '  ✗ %s\n      expected: %s\n      actual:   %s\n' "$1" "$2" "$3"
    FAILURES=$((FAILURES + 1))
  fi
}

# A fake repo shaped like a real one: an app plus a dependency in lib/, a few
# build versions, a start_erl.data naming one of them, and both archive piles.
fake_repo() { # fake_repo <dir> <current-version> <versions...>
  local dir="$1" current="$2"
  shift 2
  rm -rf "$dir"
  mkdir -p "$dir"
  {
    echo 'defmodule Fake.MixProject do'
    echo '  def project, do: [app: :'"$APP"', version: "9.9.9"]'
    echo 'end'
  } > "$dir/mix.exs"
  mkdir -p "$dir/_build/prod/rel/$APP/lib"
  mkdir -p "$dir/_build/prod/rel/$APP/releases"
  local v
  for v in "$@"; do
    mkdir -p "$dir/_build/prod/rel/$APP/lib/$APP-$v/ebin"
    : > "$dir/_build/prod/rel/$APP/lib/$APP-$v/ebin/$APP.beam"
    mkdir -p "$dir/_build/prod/rel/$APP/releases/$v"
    : > "$dir/_build/prod/rel/$APP/releases/$v/$APP.rel"
    : > "$dir/$APP-$v.tar.gz"
    : > "$dir/_build/prod/$APP-$v.tar.gz"
  done
  # a dependency, which must never be mistaken for the app
  mkdir -p "$dir/_build/prod/rel/$APP/lib/some_dep-1.0.0/ebin"
  printf '15.2.7.5 %s\n' "$current" > "$dir/_build/prod/rel/$APP/releases/start_erl.data"
}

surviving_lib_versions() { # surviving_lib_versions <dir>
  ls "$1/_build/prod/rel/$APP/lib" 2>/dev/null \
    | sed -n "s|^$APP-\([0-9.]*\)$|\1|p" | sort | tr '\n' ' ' | sed 's/ $//'
}

surviving_archives() { # surviving_archives <dir>
  ls "$1"/*.tar.gz 2>/dev/null | sed 's|.*/||' | sed 's/\.tar\.gz$//' \
    | sed "s|^$APP-||" | sort | tr '\n' ' ' | sed 's/ $//'
}

echo "prune_release_artifacts.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo ""
echo "build tree, after the build (the order the pre-push hook uses):"
fake_repo "$TMP/a" 0.1.2 0.1.0 0.1.1 0.1.2
"$SCRIPT" --repo "$TMP/a" --build-tree --apply >/dev/null 2>&1
check "keeps only the version just built" "0.1.2" "$(surviving_lib_versions "$TMP/a")"
check "start_erl.data survives" "15.2.7.5 0.1.2" "$(cat "$TMP/a/_build/prod/rel/$APP/releases/start_erl.data")"

echo ""
echo "build tree, before the build at a version bump (the trap):"
fake_repo "$TMP/b" 0.1.1 0.1.0 0.1.1 0.1.2
"$SCRIPT" --repo "$TMP/b" --build-tree --apply >/dev/null 2>&1
check "keeps two copies — which is why the hook prunes after, not before" "0.1.1 0.1.2" \
  "$(surviving_lib_versions "$TMP/b")"

echo ""
echo "build tree, never built here:"
rm -rf "$TMP/c"; mkdir -p "$TMP/c"; echo 'app: :'"$APP" > "$TMP/c/mix.exs"
OUT="$("$SCRIPT" --repo "$TMP/c" --build-tree --apply 2>&1)"; RC=$?
check "exits 0 rather than failing" "0" "$RC"
check "says nothing was there" "1" "$(echo "$OUT" | grep -c "nothing to prune")"

echo ""
echo "archives, both piles:"
fake_repo "$TMP/d" 0.1.4 0.1.0 0.1.1 0.1.2 0.1.3 0.1.4
"$SCRIPT" --repo "$TMP/d" --archives --apply >/dev/null 2>&1
check "repo root keeps the newest three" "0.1.2 0.1.3 0.1.4" "$(surviving_archives "$TMP/d")"
check "_build/prod keeps the newest three" "0.1.2 0.1.3 0.1.4" \
  "$(ls "$TMP/d"/_build/prod/*.tar.gz | sed 's|.*/||;s|\.tar\.gz$||;s|^'"$APP"'-||' | sort | tr '\n' ' ' | sed 's/ $//')"

echo ""
echo "archives, fewer than --keep-archives:"
fake_repo "$TMP/e" 0.1.0 0.1.0
"$SCRIPT" --repo "$TMP/e" --archives --apply >/dev/null 2>&1
check "keeps it" "0.1.0" "$(surviving_archives "$TMP/e")"

echo ""
echo "tarballs named after the release directory, not the app:"
# global_surface's app is `global_surface` but its tarballs are
# `global_surface_liveview-*.tar.gz`. Matching the app name alone left 31
# tarballs (half a gigabyte) on disk while reporting success.
rm -rf "$TMP/i"; mkdir -p "$TMP/i"
{ echo 'defmodule Fake.MixProject do'
  echo '  def project, do: [app: :fake_surface, version: "9.9.9"]'
  echo 'end'; } > "$TMP/i/mix.exs"
mkdir -p "$TMP/i/_build/prod/rel/fake_surface_web/lib/fake_surface-0.1.0/ebin" \
         "$TMP/i/_build/prod/rel/fake_surface_web/releases/0.1.0"
: > "$TMP/i/_build/prod/rel/fake_surface_web/lib/fake_surface-0.1.0/ebin/x.beam"
printf '15.2.7.5 0.1.0\n' > "$TMP/i/_build/prod/rel/fake_surface_web/releases/start_erl.data"
for v in 0.1.0 0.1.1 0.1.2 0.1.3; do : > "$TMP/i/fake_surface_web-$v.tar.gz"; done
: > "$TMP/i/some_other_surface-0.9.9.tar.gz"
"$SCRIPT" --repo "$TMP/i" --archives --apply >/dev/null 2>&1
check "sweeps the release-directory name too" "0.1.1 0.1.2 0.1.3" \
  "$(ls "$TMP/i"/*.tar.gz | sed 's|.*/||;s|\.tar\.gz$||;s|^fake_surface_web-||' | grep -v some_other | sort | tr '\n' ' ' | sed 's/ $//')"
check "leaves another app's tarball alone" "yes" \
  "$([ -f "$TMP/i/some_other_surface-0.9.9.tar.gz" ] && echo yes || echo no)"

echo ""
echo "two release directories in one _build:"
fake_repo "$TMP/f" 0.1.0 0.1.0
mkdir -p "$TMP/f/_build/prod/rel/other_surface/lib/other_surface-0.5.0/ebin" \
         "$TMP/f/_build/prod/rel/other_surface/releases/0.5.0"
: > "$TMP/f/_build/prod/rel/other_surface/lib/other_surface-0.5.0/ebin/other_surface.beam"
: > "$TMP/f/_build/prod/rel/other_surface/releases/start_erl.data"
"$SCRIPT" --repo "$TMP/f" --build-tree --apply >/dev/null 2>&1
check "picks the directory holding this app" "0.1.0" "$(surviving_lib_versions "$TMP/f")"
check "leaves the other app alone" "yes" \
  "$([ -d "$TMP/f/_build/prod/rel/other_surface/releases/0.5.0" ] && echo yes || echo no)"

echo ""
echo "a file git tracks is never deleted:"
# ergon_surface_hud_elixir tracks its release tarballs; the first sweep deleted
# two of them, which is a commit, not a cleanup. Five tarballs, keep three, so
# two are doomed: one tracked (stays), one untracked (goes).
rm -rf "$TMP/j"; mkdir -p "$TMP/j"
{ echo 'defmodule Fake.MixProject do'
  echo '  def project, do: [app: :fake_surface, version: "9.9.9"]'
  echo 'end'; } > "$TMP/j/mix.exs"
for v in 0.1.0 0.1.1 0.1.2 0.1.3 0.1.4; do : > "$TMP/j/fake_surface-$v.tar.gz"; done
( cd "$TMP/j" && git init -q . && git add fake_surface-0.1.0.tar.gz && \
  git -c user.email=t@t -c user.name=t commit -qm tarball ) >/dev/null 2>&1
"$SCRIPT" --repo "$TMP/j" --archives --apply > "$TMP/j/out.txt" 2>&1
check "a tracked stale tarball survives" "yes" \
  "$([ -f "$TMP/j/fake_surface-0.1.0.tar.gz" ] && echo yes || echo no)"
check "and the sweep says why" "yes" \
  "$(grep -q 'git tracks it' "$TMP/j/out.txt" && echo yes || echo no)"
check "an untracked stale tarball still goes" "0.1.0 0.1.2 0.1.3 0.1.4" \
  "$(ls "$TMP/j"/fake_surface-*.tar.gz | sed 's|.*/fake_surface-||;s|\.tar\.gz$||' | sort | tr '\n' ' ' | sed 's/ $//')"

echo ""
echo "safety:"
fake_repo "$TMP/g" 0.1.0 0.1.0
OUT="$("$SCRIPT" --repo "$TMP/g" --build-tree --apply 2>&1)"; RC=$?
check "a version is never deleted from outside the repo" "0" "$(echo "$OUT" | grep -c 'refusing to delete outside the repo')"
check "still exits 0" "0" "$RC"
OUT="$("$SCRIPT" --repo "$TMP/does-not-exist" --archives 2>&1)"; RC=$?
check "a missing repo is an error, not a shrug" "1" "$RC"

echo ""
echo "dry run is the default:"
fake_repo "$TMP/h" 0.1.2 0.1.0 0.1.1 0.1.2
"$SCRIPT" --repo "$TMP/h" --build-tree >/dev/null 2>&1
check "nothing deleted without --apply" "0.1.0 0.1.1 0.1.2" "$(surviving_lib_versions "$TMP/h")"

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "✓ all checks passed"
  exit 0
fi
echo "❌ $FAILURES check(s) failed"
exit 1
