"""End-to-end archive test against a disposable local Git fixture (no internet)."""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools/create_stable_backup.sh'


def run(*args, cwd=None):
    return subprocess.run(args, cwd=cwd, check=True, text=True,
                          capture_output=True).stdout.strip()


class SourceBackupRoundTrip(unittest.TestCase):
    def test_archive_and_bundle_round_trip_with_extra_branch(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            repo = root / 'repo'
            repo.mkdir()
            run('git', 'init', '-q', '-b', 'main', str(repo))
            run('git', 'config', 'user.name', 'Backup Test', cwd=repo)
            run('git', 'config', 'user.email', 'fixture@example.test', cwd=repo)
            req = [
                'index.html', 'LICENSE', '.nojekyll', 'manifest.webmanifest', 'sw.js',
                'explore/index.html', 'diagnose/index.html', 'children/index.html',
                'assets/stats-config.js', 'diagnose/share.js',
            ]
            for name in req:
                target = repo / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text('fixture\n' if name != '.nojekyll' else '', encoding='utf-8')
            for name in ('topics.json', 'questions.json', 'dependencies.json',
                         'cn-curriculum-standards.json', 'id-aliases.json'):
                target = repo / 'data' / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(json.dumps([{'id': name}]), encoding='utf-8')
            run('git', 'add', '-A', cwd=repo)
            run('git', 'commit', '-qm', 'stable source', cwd=repo)
            stable_sha = run('git', 'rev-parse', 'HEAD', cwd=repo)
            run('git', 'tag', 'stable-test', cwd=repo)
            run('git', 'switch', '-c', 'feature/review', cwd=repo)
            (repo / 'draft.txt').write_text('must not appear in stable ZIP', encoding='utf-8')
            run('git', 'add', 'draft.txt', cwd=repo)
            run('git', 'commit', '-qm', 'unpublished branch', cwd=repo)
            run('git', 'switch', 'main', cwd=repo)
            bare = root / 'fork.git'
            run('git', 'init', '-q', '--bare', '-b', 'main', str(bare))
            run('git', 'remote', 'add', 'origin', str(bare), cwd=repo)
            run('git', 'push', '-q', 'origin', 'main', 'feature/review', '--tags', cwd=repo)
            output = root / 'backups'
            proc = subprocess.run(['bash', str(SCRIPT), str(output)], cwd=repo,
                                  text=True, capture_output=True)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            archive = next(output.glob('*.zip'))
            bundle = next(output.glob('*.bundle'))
            with zipfile.ZipFile(archive) as zf:
                self.assertIsNone(zf.testzip())
                self.assertNotIn('draft.txt', zf.namelist())
                self.assertIn('.nojekyll', zf.namelist())
            recovered = root / 'restored'
            run('git', 'clone', '-q', '-b', 'main', str(bundle), str(recovered))
            self.assertEqual(run('git', 'rev-parse', 'HEAD', cwd=recovered), stable_sha)
            # Bundle cloned with main checked out; unmerged branch must still be in refs.
            self.assertTrue(run('git', 'show-ref', '--verify', 'refs/remotes/origin/feature/review',
                                cwd=recovered))
            self.assertEqual(run('git', 'rev-parse', 'refs/tags/stable-test', cwd=recovered), stable_sha)
            checksums = (output / 'SHA256SUMS.txt').read_text(encoding='utf-8').splitlines()
            for line in checksums:
                hexdigest, filename = line.split('  ', 1)
                self.assertEqual(hashlib.sha256((output / filename).read_bytes()).hexdigest(), hexdigest)


if __name__ == '__main__':
    unittest.main()
