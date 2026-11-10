import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT = Path(__file__).with_name("verify_learning_data.py")
SPEC = importlib.util.spec_from_file_location("verify_learning_data", SCRIPT)
VERIFY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFY)


class FindExamFilesTests(unittest.TestCase):
    def test_uses_learning_data_dir_override(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            exam_file = Path(temp_dir, "track-a", "exams.json")
            exam_file.parent.mkdir()
            exam_file.write_text("[]", encoding="utf-8")

            with patch.dict(os.environ, {"LEARNING_DATA_DIR": temp_dir}):
                self.assertEqual(VERIFY.find_exam_files(), [exam_file.as_posix()])

    def test_keeps_assets_data_as_default(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            exam_file = Path(temp_dir, "assets", "data", "track-b", "exams.json")
            exam_file.parent.mkdir(parents=True)
            exam_file.write_text("[]", encoding="utf-8")

            original_cwd = os.getcwd()
            try:
                os.chdir(temp_dir)
                with patch.dict(os.environ, {}, clear=True):
                    self.assertEqual(
                        VERIFY.find_exam_files(),
                        ["assets/data/track-b/exams.json"],
                    )
            finally:
                os.chdir(original_cwd)


if __name__ == "__main__":
    unittest.main()
