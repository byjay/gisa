#!/usr/bin/env python3
"""assets/data/**의 문제 JSON을 3계층으로 분해하여 R2 업로드/D1 적재용 파일을 생성한다.

계층:
  1) meta      → questions_meta (공개 가능: 과목/토픽/빈도/순서, 정답 없음)
  2) body      → R2 content/{track}/{exam}/{qid}.json (문제 본문, 정답 없음)
  3) private   → answers_private (정답 + 해설, 서버 전용)

⚠️ 이 스크립트는 "준비" 단계다. 실제 업로드는:
   - meta/private → SQL로 D1에 INSERT (out/d1_seed.sql)
   - body         → wrangler r2 object put 로 업로드 (out/r2/ 디렉토리)

사용:
  python3 split_content_for_r2.py --data-dir ../../assets/data --out ./out
"""
import argparse
import json
import os
import glob


def sql_escape(s):
    if s is None:
        return "NULL"
    return "'" + str(s).replace("'", "''") + "'"


def process_track(track_dir, track, out_dir, sql_lines):
    exams_path = os.path.join(track_dir, "exams.json")
    if not os.path.exists(exams_path):
        return 0
    with open(exams_path, encoding="utf-8") as f:
        data = json.load(f)

    # exams.json 구조는 프로젝트마다 다를 수 있으므로 방어적으로 처리.
    # 기대: [{exam_label, questions:[{no, subject, topic, question, options, answer, explanation, difficulty, freq_score, image, has_image}]}]
    count = 0
    exams = data if isinstance(data, list) else data.get("exams", [])
    for exam in exams:
        exam_id = exam.get("exam_label") or exam.get("id") or "unknown"
        questions = exam.get("questions", [])
        r2dir = os.path.join(out_dir, "r2", "content", track, exam_id)
        os.makedirs(r2dir, exist_ok=True)
        for order_idx, q in enumerate(questions):
            no = q.get("no", order_idx + 1)
            subject = q.get("subject", "")
            qid = f"{track}|{exam_id}|{subject}|{no}"

            # (1) meta → D1
            sql_lines.append(
                "INSERT OR REPLACE INTO questions_meta "
                "(qid, track, exam_id, subject, topic, difficulty, freq_score, has_image, order_idx) VALUES "
                f"({sql_escape(qid)}, {sql_escape(track)}, {sql_escape(exam_id)}, {sql_escape(subject)}, "
                f"{sql_escape(q.get('topic','기타'))}, {int(q.get('difficulty',2))}, "
                f"{float(q.get('freq_score',0))}, {1 if q.get('has_image') else 0}, {order_idx});"
            )

            # (2) private(정답/해설) → D1 (서버 전용)
            sql_lines.append(
                "INSERT OR REPLACE INTO answers_private (qid, answer, explanation) VALUES "
                f"({sql_escape(qid)}, {int(q.get('answer',0))}, {sql_escape(q.get('explanation',''))});"
            )

            # (3) body(정답 제외) → R2 파일
            body = {
                "qid": qid,
                "no": no,
                "subject": subject,
                "topic": q.get("topic", "기타"),
                "question": q.get("question", ""),
                "options": q.get("options", []),
                "has_image": bool(q.get("has_image")),
                "image": q.get("image"),
                "difficulty": q.get("difficulty", 2),
                "freq_score": q.get("freq_score", 0),
                # answer/explanation 의도적으로 제외
            }
            safe = qid.replace("|", "_").replace("/", "_")
            with open(os.path.join(r2dir, f"{safe}.json"), "w", encoding="utf-8") as bf:
                json.dump(body, bf, ensure_ascii=False)
            count += 1
    return count


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", required=True)
    ap.add_argument("--out", default="./out")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    sql_lines = []
    total = 0
    for track_dir in sorted(glob.glob(os.path.join(args.data_dir, "*"))):
        if not os.path.isdir(track_dir):
            continue
        track = os.path.basename(track_dir)
        if track == "common":
            continue
        n = process_track(track_dir, track, args.out, sql_lines)
        if n:
            print(f"  {track}: {n} questions")
        total += n

    seed_path = os.path.join(args.out, "d1_seed.sql")
    with open(seed_path, "w", encoding="utf-8") as f:
        f.write("\n".join(sql_lines))
    print(f"\n총 {total}문항 처리 완료")
    print(f"  D1 시드: {seed_path}")
    print(f"  R2 본문: {os.path.join(args.out, 'r2', 'content')}/")
    print("\n다음 단계:")
    print("  wrangler d1 execute gisaclub-db --file=out/d1_seed.sql")
    print("  # R2 업로드 예시:")
    print("  find out/r2/content -name '*.json' | while read f; do \\")
    print("    key=${f#out/r2/}; wrangler r2 object put gisaclub-content/$key --file=\"$f\"; done")


if __name__ == "__main__":
    main()
