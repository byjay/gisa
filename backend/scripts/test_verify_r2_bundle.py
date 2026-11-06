import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[1]
VALIDATOR_PATH = SCRIPT_DIR / "verify_r2_bundle.py"


def load_validator():
    if not VALIDATOR_PATH.is_file():
        return None
    spec = importlib.util.spec_from_file_location("verify_r2_bundle", VALIDATOR_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


VALIDATOR = load_validator()


class VerifyR2BundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.data = self.root / "backend" / "data"
        self.study = self.data / "study"
        self.theory = self.data / "theory"
        self.catalog = self.root / "backend" / "catalog" / "tracks.json"
        self.scripts = self.root / "backend" / "scripts"
        self.bundle = self.scripts / "out"
        self.migrations = self.root / "backend" / "cloudflare" / "migrations"
        self.track = "electrician"
        self.exam_id = "2024_1"
        self.question = {
            "no": 1,
            "subject": "회로이론",
            "topic": "기초",
            "question": "fixture only",
            "options": ["가", "나", "다", "라"],
            "answer": 2,
            "explanation": "private fixture text",
            "difficulty": 2,
            "freq_score": 1.25,
            "has_image": True,
            "image": "images/sample.png",
        }
        track_dir = self.study / self.track
        (track_dir / "images").mkdir(parents=True)
        (self.theory / self.track).mkdir(parents=True)
        self.catalog.parent.mkdir(parents=True)
        self.scripts.mkdir(parents=True)
        self.migrations.mkdir(parents=True)
        (track_dir / "exams.json").write_text(json.dumps([{
            "exam_label": self.exam_id,
            "label": "2024년 1회",
            "year": 2024,
            "session": "1",
            "questions": [self.question],
        }]), encoding="utf-8")
        (track_dir / "repeat_questions.json").write_text('{"items": [1]}\n', encoding="utf-8")
        (track_dir / "images" / "sample.png").write_bytes(b"fixture image")
        (self.theory / self.track / "01.md").write_text("fixture theory\n", encoding="utf-8")
        self.catalog.write_text(json.dumps({
            "schemaVersion": 1,
            "tracks": [{"id": self.track, "name": "fixture", "questionCount": 0}],
        }), encoding="utf-8")
        shutil.copytree(PROJECT_ROOT / "backend" / "cloudflare" / "migrations", self.migrations, dirs_exist_ok=True)
        self._build_bundle()

    def tearDown(self):
        self.temp.cleanup()

    def _build_bundle(self):
        sys.path.insert(0, str(SCRIPT_DIR))
        try:
            import split_content_for_r2 as splitter
            splitter.__file__ = str(self.scripts / "split_content_for_r2.py")
            self.bundle.mkdir(parents=True, exist_ok=True)
            sql_lines = []
            splitter.process_track(self.study / self.track, self.track, self.bundle, sql_lines)
            splitter.copy_remote_assets(self.study, self.bundle)
            (self.bundle / "d1_seed.sql").write_text("\n".join(sql_lines), encoding="utf-8")
        finally:
            sys.path.remove(str(SCRIPT_DIR))

    def test_validator_is_available(self):
        self.assertIsNotNone(VALIDATOR, "verify_r2_bundle.py must exist before bundle checks can run")

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_current_bundle_passes_all_source_checks(self):
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertEqual(result.errors, [])
        self.assertEqual(result.questions, 1)
        self.assertEqual(result.r2_objects, 6)

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_missing_catalog_is_reported(self):
        (self.bundle / "r2" / "catalog" / "tracks.json").unlink()
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertTrue(any("catalog" in error for error in result.errors))

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_stale_study_copy_is_reported(self):
        target = self.bundle / "r2" / "study" / self.track / "repeat_questions.json"
        target.write_text('{"items": [0]}\n', encoding="utf-8")
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertTrue(any("repeat_questions.json" in error for error in result.errors))

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_question_qid_drift_is_reported(self):
        paper_path = self.bundle / "r2" / "content" / self.track / self.exam_id / "paper.json"
        paper = json.loads(paper_path.read_text(encoding="utf-8"))
        paper["questions"][0]["qid"] = "wrong-qid"
        paper_path.write_text(json.dumps(paper), encoding="utf-8")
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertTrue(any("question body differs" in error for error in result.errors))

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_d1_qid_drift_is_reported(self):
        (self.bundle / "d1_seed.sql").write_text("", encoding="utf-8")
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertTrue(any("D1 questions_meta qid set" in error for error in result.errors))
        self.assertTrue(any("D1 answers_private qid set" in error for error in result.errors))

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_unexpected_r2_object_is_reported(self):
        extra = self.bundle / "r2" / "content" / self.track / "extra.json"
        extra.write_text("{}", encoding="utf-8")
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertTrue(any("unexpected R2 object" in error for error in result.errors))

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_unapproved_study_json_is_rejected_even_when_copied(self):
        (self.study / self.track / "answers_private.json").write_text(
            '{"answer": 2}', encoding="utf-8"
        )
        self._build_bundle()
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertTrue(any("unapproved study source" in error for error in result.errors))

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_json_type_drift_is_reported(self):
        paper_path = self.bundle / "r2" / "content" / self.track / self.exam_id / "paper.json"
        paper = json.loads(paper_path.read_text(encoding="utf-8"))
        paper["questions"][0]["has_image"] = 1
        paper_path.write_text(json.dumps(paper), encoding="utf-8")
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertTrue(any("question body differs" in error for error in result.errors))

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_missing_source_image_used_by_question_is_reported(self):
        image_path = self.study / self.track / "images" / "sample.png"
        image_path.unlink()
        (self.bundle / "r2" / "images" / self.track / "sample.png").unlink()
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertTrue(any("question image reference missing" in error for error in result.errors))

    @unittest.skipIf(VALIDATOR is None, "validator implementation not added yet")
    def test_private_answer_fields_are_rejected_without_echoing_values(self):
        paper_path = self.bundle / "r2" / "content" / self.track / self.exam_id / "paper.json"
        paper = json.loads(paper_path.read_text(encoding="utf-8"))
        paper["questions"][0]["answer"] = self.question["answer"]
        paper["questions"][0]["explanation"] = self.question["explanation"]
        paper_path.write_text(json.dumps(paper), encoding="utf-8")
        result = VALIDATOR.validate_bundle(self.study, self.bundle, self.catalog, self.migrations)
        self.assertTrue(any("private" in error for error in result.errors))
        self.assertNotIn(self.question["explanation"], " ".join(result.errors))


if __name__ == "__main__":
    unittest.main()
