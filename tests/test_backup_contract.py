"""Dependency-free static checks for backup workflow safety boundaries.

These checks are deliberately narrow: they cannot guarantee browser behavior
or secure arbitrary upstream code. Test actual archive recovery separately.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / '.github/workflows/backup-stable.yml'
SCRIPT = ROOT / 'tools/create_stable_backup.sh'

class BackupContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = WORKFLOW.read_text(encoding='utf-8')
        cls.script = SCRIPT.read_text(encoding='utf-8')

    def test_scope_is_stable_main_only(self):
        self.assertRegex(self.workflow, r'(?m)^\s+branches:\s*\[main\]\s*$')
        self.assertRegex(self.workflow, r'(?m)^\s+ref:\s*main\s*$')
        self.assertIn('refs/heads/main', self.script)

    def test_workflow_token_read_only(self):
        self.assertRegex(self.workflow, r'(?m)^permissions:\s*\n\s+contents:\s*read\s*$')
        self.assertNotRegex(self.workflow, r'(?m)^\s+pull-requests:\s*write\s*$')

    def test_backup_never_publishes_or_pushes(self):
        self.assertNotRegex(self.script, r'\bgit\s+push\b')
        self.assertNotRegex(self.script, r'\b(firebase\s+deploy|wrangler\s+deploy|gh\s+pr\s+merge)\b')
        self.assertNotIn('deploy-pages', self.workflow)

    def test_has_bundle_archive_checksums_and_restore_test(self):
        for token in ('git archive', 'git bundle create', 'git bundle verify',
                      'git clone --quiet --branch main', 'sha256sum',
                      "zipfile.ZipFile", 'zf.testzip()'):
            self.assertIn(token, self.script)

    def test_artifact_expiry_explicit(self):
        self.assertIn('actions/upload-artifact@v4', self.workflow)
        self.assertRegex(self.workflow, r'(?m)^\s+retention-days:\s*30\s*$')

if __name__ == '__main__':
    unittest.main()
