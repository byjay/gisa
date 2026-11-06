#!/usr/bin/env python3
"""Verify that a local D1/R2 content bundle matches its private source data."""

import argparse
import json
import re
import sqlite3
from dataclasses import dataclass, field
from pathlib import Path


PRIVATE_FIELDS = {"answer", "explanation"}
TRACK_STUDY_FILES = {
    "study_plan.json", "study_guide.json", "theory_slides.json",
    "subject_summary.json", "exam_info_2026.json", "formula_guide.json",
    "silgi.json", "topic_freq.json", "solution_recipes.json",
    "mnemonics.json", "videos.json", "lessons.json", "repeat_questions.json",
}
COMMON_STUDY_FILES = {"basics_dict.json", "circuit_guide.json"}
SAFE_TRACK = re.compile(r"^[a-z0-9_]{1,64}$")
SAFE_EXAM = re.compile(r"^[A-Za-z0-9_-]{1,80}$")
SAFE_IMAGE_PART = re.compile(r"^[A-Za-z0-9_.-]+$")


@dataclass
class BundleResult:
    errors: list[str] = field(default_factory=list)
    tracks: int = 0
    exams: int = 0
    questions: int = 0
    r2_objects: int = 0
    source_copies: int = 0
    d1_meta_rows: int = 0
    d1_private_rows: int = 0


def _load_json(path: Path, label: str, result: BundleResult):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        result.errors.append(f"invalid or missing JSON: {label}")
        return None


def _has_private_fields(value):
    if isinstance(value, dict):
        return any(key in PRIVATE_FIELDS or _has_private_fields(item) for key, item in value.items())
    if isinstance(value, list):
        return any(_has_private_fields(item) for item in value)
    return False


def _same_json(actual, expected):
    try:
        return json.dumps(actual, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) == json.dumps(
            expected, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False
        )
    except (TypeError, ValueError):
        return False


def _copy_matches(source: Path, target: Path, key: str, result: BundleResult):
    result.source_copies += 1
    try:
        if not target.is_file() or not _same_file_content(source, target):
            result.errors.append(f"source copy mismatch: {key}")
    except OSError:
        result.errors.append(f"source copy unreadable: {key}")


def _same_file_content(source: Path, target: Path):
    with source.open("rb") as left, target.open("rb") as right:
        while True:
            left_chunk = left.read(1024 * 1024)
            right_chunk = right.read(1024 * 1024)
            if left_chunk != right_chunk:
                return False
            if not left_chunk:
                return True


def _expected_body(track, exam_id, order_idx, question):
    number = question.get("no", order_idx + 1)
    subject = question.get("subject", "")
    qid = f"{track}|{exam_id}|{subject}|{number}"
    body = {
        "qid": qid,
        "no": number,
        "subject": subject,
        "topic": question.get("topic", "기타"),
        "question": question.get("question", ""),
        "options": question.get("options", []),
        "has_image": bool(question.get("has_image")),
        "image": question.get("image"),
        "difficulty": question.get("difficulty", 2),
        "freq_score": question.get("freq_score", 0),
    }
    return qid, body


def _add_copied_sources(study_dir: Path, theory_dir: Path, r2_dir: Path, result: BundleResult):
    expected_keys = set()
    for track_dir in sorted(study_dir.glob("*")):
        if not track_dir.is_dir():
            continue
        track = track_dir.name
        target_group = "common" if track == "common" else track
        for source in sorted(track_dir.glob("*.json")):
            if source.name == "exams.json":
                continue
            allowed_files = COMMON_STUDY_FILES if track == "common" else TRACK_STUDY_FILES
            if source.name not in allowed_files:
                result.errors.append(f"unapproved study source: {track}/{source.name}")
                continue
            key = f"study/{target_group}/{source.name}"
            expected_keys.add(key)
            _copy_matches(source, r2_dir / key, key, result)

        image_dir = track_dir / "images"
        if track != "common" and image_dir.is_dir():
            for source in sorted(image_dir.rglob("*")):
                if not source.is_file():
                    continue
                relative = source.relative_to(image_dir).as_posix()
                key = f"images/{track}/{relative}"
                expected_keys.add(key)
                _copy_matches(source, r2_dir / key, key, result)

    schedule = study_dir / "qnet_schedule.json"
    if schedule.is_file():
        key = "study/qnet/qnet_schedule.json"
        expected_keys.add(key)
        _copy_matches(schedule, r2_dir / key, key, result)

    if theory_dir.is_dir():
        for track_dir in sorted(theory_dir.glob("*")):
            if not track_dir.is_dir():
                continue
            for source in sorted(track_dir.glob("*.md")):
                key = f"theory/{track_dir.name}/{source.name}"
                expected_keys.add(key)
                _copy_matches(source, r2_dir / key, key, result)
    return expected_keys


def _verify_d1(seed_path: Path, migrations_dir: Path, expected_qids: set[str], result: BundleResult):
    connection = sqlite3.connect(":memory:")
    try:
        migrations = sorted(migrations_dir.glob("*.sql"))
        if not migrations:
            result.errors.append("D1 migrations missing")
            return
        for migration in migrations:
            try:
                connection.executescript(migration.read_text(encoding="utf-8"))
            except (OSError, sqlite3.Error):
                result.errors.append(f"D1 migration failed: {migration.name}")
                return
        try:
            connection.executescript(seed_path.read_text(encoding="utf-8"))
            meta_qids = {row[0] for row in connection.execute("SELECT qid FROM questions_meta")}
            private_qids = {row[0] for row in connection.execute("SELECT qid FROM answers_private")}
        except (OSError, UnicodeError, sqlite3.Error):
            result.errors.append("D1 seed failed against local migrations")
            return
        result.d1_meta_rows = len(meta_qids)
        result.d1_private_rows = len(private_qids)
        if meta_qids != expected_qids:
            result.errors.append("D1 questions_meta qid set differs from source")
        if private_qids != expected_qids:
            result.errors.append("D1 answers_private qid set differs from source")
    finally:
        connection.close()


def validate_bundle(study_dir: Path, bundle_dir: Path, catalog_path: Path, migrations_dir: Path):
    study_dir = Path(study_dir)
    bundle_dir = Path(bundle_dir)
    catalog_path = Path(catalog_path)
    migrations_dir = Path(migrations_dir)
    result = BundleResult()
    r2_dir = bundle_dir / "r2"
    catalog = _load_json(catalog_path, "source catalog", result)
    if not isinstance(catalog, dict) or catalog.get("schemaVersion") != 1 or not isinstance(catalog.get("tracks"), list):
        result.errors.append("source catalog schema invalid")
        return result

    expected_qids = set()
    expected_r2_keys = set()
    referenced_image_keys = set()
    expected_catalog = json.loads(json.dumps(catalog, ensure_ascii=False))
    catalog_tracks = expected_catalog["tracks"]
    seen_tracks = set()
    for track_item in catalog_tracks:
        track = track_item.get("id") if isinstance(track_item, dict) else None
        if not isinstance(track, str) or not SAFE_TRACK.fullmatch(track) or track in seen_tracks:
            result.errors.append("catalog track id invalid or duplicated")
            continue
        seen_tracks.add(track)
        source_path = study_dir / track / "exams.json"
        source_data = _load_json(source_path, f"source/{track}/exams.json", result)
        if source_data is None:
            continue
        exams = source_data if isinstance(source_data, list) else source_data.get("exams", [])
        if not isinstance(exams, list):
            result.errors.append(f"source exam list invalid: {track}")
            continue
        result.tracks += 1
        expected_index = []
        track_question_count = 0
        expected_r2_keys.add(f"content/{track}/_index.json")
        for exam in exams:
            if not isinstance(exam, dict):
                result.errors.append(f"source exam invalid: {track}")
                continue
            exam_id = exam.get("exam_label") or exam.get("id") or "unknown"
            if not isinstance(exam_id, str) or not SAFE_EXAM.fullmatch(exam_id):
                result.errors.append(f"unsafe exam id: {track}")
                continue
            questions = exam.get("questions", [])
            if not isinstance(questions, list):
                result.errors.append(f"source questions invalid: {track}/{exam_id}")
                continue
            expected_index.append({
                "id": exam_id,
                "label": exam.get("label") or exam_id,
                "year": int(exam.get("year", 0)),
                "session": str(exam.get("session", "")),
                "question_count": len(questions),
            })
            result.exams += 1
            track_question_count += len(questions)
            paper_key = f"content/{track}/{exam_id}/paper.json"
            expected_r2_keys.add(paper_key)
            paper = _load_json(r2_dir / paper_key, paper_key, result)
            if not isinstance(paper, dict) or not isinstance(paper.get("questions"), list):
                continue
            actual_questions = paper["questions"]
            if len(actual_questions) != len(questions):
                result.errors.append(f"question count differs: {paper_key}")
            if _has_private_fields(actual_questions):
                result.errors.append(f"private answer field in R2: {paper_key}")
            for order_idx, source_question in enumerate(questions):
                qid, expected_body = _expected_body(track, exam_id, order_idx, source_question)
                if qid in expected_qids:
                    result.errors.append(f"duplicate source qid: {track}/{exam_id}")
                expected_qids.add(qid)
                result.questions += 1
                if order_idx < len(actual_questions) and not _same_json(actual_questions[order_idx], expected_body):
                    result.errors.append(f"question body differs: {paper_key} item {order_idx}")
                image = source_question.get("image")
                if image:
                    if not isinstance(image, str):
                        result.errors.append(f"question image path invalid: {paper_key} item {order_idx}")
                    else:
                        parts = image.split("/")
                        if parts[0] == "images":
                            parts = parts[1:]
                        if not parts or any(
                            part in ("", ".", "..") or not SAFE_IMAGE_PART.fullmatch(part)
                            for part in parts
                        ):
                            result.errors.append(f"question image path invalid: {paper_key} item {order_idx}")
                        else:
                            referenced_image_keys.add(f"images/{track}/{'/'.join(parts)}")

        index_key = f"content/{track}/_index.json"
        index = _load_json(r2_dir / index_key, index_key, result)
        if not isinstance(index, dict) or index.get("track") != track or not _same_json(index.get("exams"), expected_index):
            result.errors.append(f"exam index differs: {track}")
        track_item["questionCount"] = track_question_count

    catalog_key = "catalog/tracks.json"
    expected_r2_keys.add(catalog_key)
    bundled_catalog = _load_json(r2_dir / catalog_key, catalog_key, result)
    if not _same_json(bundled_catalog, expected_catalog):
        result.errors.append("R2 catalog differs from current source")

    expected_r2_keys |= _add_copied_sources(study_dir, study_dir.parent / "theory", r2_dir, result)
    for key in sorted(referenced_image_keys - expected_r2_keys):
        result.errors.append(f"question image reference missing: {key}")
    try:
        actual_r2_keys = {
            path.relative_to(r2_dir).as_posix()
            for path in r2_dir.rglob("*")
            if path.is_file()
        }
    except OSError:
        actual_r2_keys = set()
        result.errors.append("R2 bundle inventory unreadable")
    result.r2_objects = len(actual_r2_keys)
    for key in sorted(expected_r2_keys - actual_r2_keys):
        result.errors.append(f"R2 object missing: {key}")
    for key in sorted(actual_r2_keys - expected_r2_keys):
        result.errors.append(f"unexpected R2 object: {key}")

    _verify_d1(bundle_dir / "d1_seed.sql", migrations_dir, expected_qids, result)
    return result


def main():
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, default=repo_root / "backend" / "data" / "study")
    parser.add_argument("--bundle", type=Path, default=repo_root / "backend" / "scripts" / "out")
    parser.add_argument("--catalog", type=Path, default=repo_root / "backend" / "catalog" / "tracks.json")
    parser.add_argument("--migrations", type=Path, default=repo_root / "backend" / "cloudflare" / "migrations")
    args = parser.parse_args()
    result = validate_bundle(args.data_dir, args.bundle, args.catalog, args.migrations)
    print(
        "tracks={0} exams={1} questions={2} r2_objects={3} source_copies={4} "
        "d1_meta_rows={5} d1_private_rows={6}".format(
            result.tracks,
            result.exams,
            result.questions,
            result.r2_objects,
            result.source_copies,
            result.d1_meta_rows,
            result.d1_private_rows,
        )
    )
    if result.errors:
        for error in result.errors:
            print(f"ERROR {error}")
        return 1
    print("bundle verification: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
