"""Fixture-only tests; real GitHub data must also be checked in Actions."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().parents[1] / "tools" / "check_upstream_candidate.py"
spec = importlib.util.spec_from_file_location("checker", CHECKER)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class SafeUpstreamTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for filename in checker.REQUIRED_FILES:
            file = self.root / filename
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("fixture", encoding="utf-8")
        for filename in checker.DATA_FILES:
            file = self.root / "data" / filename
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text(json.dumps([{"id": "demo"}]), encoding="utf-8")
        (self.root / "LICENSE").write_text("Attribution-NonCommercial 4.0 International", encoding="utf-8")
        (self.root / "index.html").write_text("\n".join(f'<a data-subject="{x}">subject</a>' for x in checker.SUBJECTS), encoding="utf-8")
        (self.root / "assets/stats-config.js").write_text("window.CNM_STATS = {\n  cloudflareToken: '',\n  endpoint: '',\n  onEvent: null\n};\n", encoding="utf-8")
        (self.root / "diagnose/share.js").write_text("var SHARE_URL = new URL('../?from=share', window.location.href).href;", encoding="utf-8")

    def test_valid_candidate(self):
        self.assertEqual(checker.check(self.root), [])

    def test_reenabled_tracking_rejected(self):
        f = self.root / "assets/stats-config.js"
        f.write_text("window.CNM_STATS = { cloudflareToken: '',\nendpoint: 'https://example.com/collect',\n};", encoding="utf-8")
        self.assertTrue(any("analytics" in e for e in checker.check(self.root)))

    def test_share_redirect_to_author_rejected(self):
        (self.root / "diagnose/share.js").write_text("var SHARE_URL = 'https://math.pansgo.com/?from=share';", encoding="utf-8")
        self.assertTrue(any("Share URL" in e for e in checker.check(self.root)))

    def test_missing_or_bad_questions_rejected(self):
        f = self.root / "data/questions.json"
        f.write_text("broken!", encoding="utf-8")
        self.assertTrue(any("questions.json" in e for e in checker.check(self.root)))

    def test_eight_subjects_required(self):
        (self.root / "index.html").write_text('<a data-subject="math">数学</a>', encoding="utf-8")
        self.assertTrue(any("english" in e for e in checker.check(self.root)))

    def test_license_required(self):
        (self.root / "LICENSE").unlink()
        self.assertTrue(any("LICENSE" in e for e in checker.check(self.root)))

    def test_comment_does_not_fake_safe_config(self):
        (self.root / "assets/stats-config.js").write_text("// endpoint: '',\nendpoint: 'https://tracker.invalid',\ncloudflareToken: '',", encoding="utf-8")
        self.assertTrue(any("endpoint" in e for e in checker.check(self.root)))


if __name__ == "__main__":
    unittest.main()
