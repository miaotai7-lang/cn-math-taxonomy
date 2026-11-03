#!/usr/bin/env bash
# Create source ZIP + complete Git bundle for stable main. Never push/deploy.
set -euo pipefail

if [ "$#" -ne 1 ]; then
  printf 'Usage: %s OUTPUT_DIRECTORY\n' "$0" >&2
  exit 2
fi

destination="$1"
mkdir -p "$destination"
destination="$(cd "$destination" && pwd -P)"

if [ "$(git branch --show-current)" != "main" ]; then
  echo 'ERROR: backup must run from checked-out main.' >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo 'ERROR: Git working tree is not clean; aborting backup.' >&2
  exit 1
fi

# Include all branches from *our own fork*, not just checkout history.
# It does not fetch, execute, or deploy original author's latest code.
git fetch --no-tags origin '+refs/heads/*:refs/remotes/origin/*'
sha="$(git rev-parse refs/heads/main)"
short_sha="${sha:0:12}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="$destination/cnm-main-${short_sha}.zip"
bundle="$destination/cnm-history-${short_sha}.bundle"

# Archive the exact stable commit, never unmerged review PR content.
git archive --format=zip --output="$archive" "$sha"
git bundle create "$bundle" --all
git bundle verify "$bundle"

checkdir="$(mktemp -d)"
trap 'rm -rf "$checkdir"' EXIT
# Ensure the bundle really restores a fresh repository with the same main SHA.
git clone --quiet --branch main "$bundle" "$checkdir/recovered"
restored_sha="$(git -C "$checkdir/recovered" rev-parse refs/heads/main)"
if [ "$restored_sha" != "$sha" ]; then
  echo "ERROR: restored bundle SHA mismatch ($restored_sha != $sha)." >&2
  exit 1
fi

python3 - "$archive" <<'PY'
from pathlib import Path
import json
import sys
import zipfile

archive = Path(sys.argv[1])
required = {
    'index.html', 'LICENSE', '.nojekyll', 'manifest.webmanifest',
    'sw.js', 'data/topics.json', 'data/questions.json',
    'data/dependencies.json', 'data/cn-curriculum-standards.json',
    'data/id-aliases.json', 'explore/index.html', 'diagnose/index.html',
    'children/index.html', 'assets/stats-config.js', 'diagnose/share.js',
}
with zipfile.ZipFile(archive, 'r') as zf:
    bad = zf.testzip()
    if bad is not None:
        raise SystemExit(f'ERROR: corrupt archive member {bad}')
    files = set(zf.namelist())
    missing = sorted(required - files)
    if missing:
        raise SystemExit(f'ERROR: ZIP missing expected site files: {missing}')
    for item in ('topics.json', 'questions.json', 'dependencies.json',
                 'cn-curriculum-standards.json', 'id-aliases.json'):
        with zf.open('data/' + item) as reader:
            obj = json.load(reader)
        if not isinstance(obj, (list, dict)) or not obj:
            raise SystemExit(f'ERROR: empty/invalid learning dataset {item}')
print('PASS: ZIP integrity, required website files, and five learning datasets')
PY

(
  cd "$destination"
  sha256sum "$(basename "$archive")" "$(basename "$bundle")" > SHA256SUMS.txt
)
cat > "$destination/RESTORE_INFO.txt" <<EOF
Project: miaotai7-lang/cn-math-taxonomy
Source branch: main
Stable commit SHA: $sha
Backup time UTC: $timestamp

Files:
  $(basename "$archive")  -> complete tracked source at stable main, no git history
  $(basename "$bundle") -> local Git branches/tags/history as fetched at backup time
  SHA256SUMS.txt -> integrity checks

Verification on Linux/macOS/Git Bash:
  sha256sum -c SHA256SUMS.txt
  git clone -b main $(basename "$bundle") restored-source

Do NOT automatically deploy or force-push a restored repository.
Backups exclude user browser localStorage/diagnosis/child-profile records.
GitHub Actions artifacts expire; download/copy the ZIP + Bundle to independent storage.
EOF

echo "PASS: backed up main $sha"
echo "Backup files are in: $destination"
