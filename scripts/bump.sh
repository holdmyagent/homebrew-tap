#!/usr/bin/env bash
# Bump a Hold My Agent formula to its package's latest release on PyPI.
#
# Usage: scripts/bump.sh [PKG]   (PKG = holdmyagent [default] | hold-warden)
#   holdmyagent -> Formula/hma.rb        hold-warden -> Formula/hma-warden.rb
#
# Fetches PyPI metadata, rewrites the formula's url/sha256 to the latest
# sdist, and regenerates the resource (dependency) blocks with
# `brew update-python-resources`. Only edits the formula -- this script does
# NOT audit, install, or test it. Review the diff and commit it yourself.
#
# Must be run from within a real `brew tap`-cloned copy of this repo (i.e.
# a directory under $(brew --repository)/Library/Taps/...): Homebrew's
# `update-python-resources` refuses to operate on a formula file that isn't
# inside a known tap.
#
# Before committing, audit/install/test the result. Homebrew >=6 removed the
# bare-path `brew audit`/`brew install` flow (a formula must belong to a
# known tap), so use a throwaway tap-scratch tap instead -- see the
# "Testing formula changes before committing" section of README.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Which package/formula to bump. No arg keeps the original holdmyagent behavior.
PKG="${1:-holdmyagent}"
case "$PKG" in
  holdmyagent)  FORMULA="$REPO_ROOT/Formula/hma.rb";        NAME="hma" ;;
  hold-warden)  FORMULA="$REPO_ROOT/Formula/hma-warden.rb"; NAME="hma-warden" ;;
  *)
    echo "ERROR: unknown package '$PKG' (expected: holdmyagent | hold-warden)" >&2
    exit 1
    ;;
esac

if [ ! -f "$FORMULA" ]; then
  echo "ERROR: $FORMULA not found" >&2
  exit 1
fi

echo "==> Fetching $PKG metadata from PyPI..."
META_JSON="$(curl -fsSL "https://pypi.org/pypi/$PKG/json")"
if [ -z "$META_JSON" ]; then
  echo "ERROR: empty response fetching PyPI metadata" >&2
  exit 1
fi

VERSION="$(printf '%s' "$META_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["version"])')"
if [ -z "$VERSION" ]; then
  echo "ERROR: could not determine latest version from PyPI response" >&2
  exit 1
fi
echo "==> Latest version: $VERSION"

SDIST_INFO="$(printf '%s' "$META_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
sdist = next((f for f in d["urls"] if f["packagetype"] == "sdist"), None)
if sdist is None:
    print("ERROR: no sdist found for latest release", file=sys.stderr)
    sys.exit(1)
print(sdist["url"], sdist["digests"]["sha256"])
')"
NEW_URL="$(printf '%s' "$SDIST_INFO" | cut -d' ' -f1)"
NEW_SHA256="$(printf '%s' "$SDIST_INFO" | cut -d' ' -f2)"

if [ -z "$NEW_URL" ] || [ -z "$NEW_SHA256" ]; then
  echo "ERROR: could not determine sdist url/sha256 for $VERSION" >&2
  exit 1
fi
echo "==> sdist: $NEW_URL"
echo "==> sha256: $NEW_SHA256"

cp "$FORMULA" "$FORMULA.bak"
trap 'rm -f "$FORMULA.bak"' EXIT

# Only the top-level package's url/sha256 lines use 2-space indent;
# resource-block url/sha256 lines are indented 4 spaces, so these
# anchored patterns touch only the main package stanza.
sed -i '' -E "s|^  url \".*\"|  url \"${NEW_URL}\"|" "$FORMULA"
sed -i '' -E "s|^  sha256 \".*\"|  sha256 \"${NEW_SHA256}\"|" "$FORMULA"

if ! grep -qF "$NEW_URL" "$FORMULA"; then
  echo "ERROR: url substitution failed, restoring backup" >&2
  cp "$FORMULA.bak" "$FORMULA"
  exit 1
fi

echo "==> Regenerating resource blocks (brew update-python-resources)..."
if ! brew update-python-resources --install-dependencies "$FORMULA"; then
  echo "ERROR: brew update-python-resources failed, restoring backup." >&2
  echo "Note: PyPI releases under 24h old are excluded by Homebrew's" >&2
  echo "release-cooldown safety check -- if the release is that recent," >&2
  echo "retry after it ages past 24h." >&2
  cp "$FORMULA.bak" "$FORMULA"
  exit 1
fi

echo "==> Diff:"
diff --stat "$FORMULA.bak" "$FORMULA" || true
diff -u "$FORMULA.bak" "$FORMULA" || true

echo
echo "==> Done. Audit/install/test before committing -- see README.md's"
echo "    'Testing formula changes before committing' section (Homebrew >=6"
echo "    needs a tap-scratch tap; bare-path brew audit/install no longer"
echo "    works). Then commit manually, e.g.:"
echo "    git -C \"$REPO_ROOT\" add ${FORMULA#"$REPO_ROOT"/}"
echo "    git -C \"$REPO_ROOT\" commit -m \"chore: bump $NAME to $VERSION\""
