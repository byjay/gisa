# -*- coding: utf-8 -*-
"""has_image=True인 모든 문항에 대해, 이미 생성된 크롭 PNG(images/{eid}_{no:03d}.png)가
존재하면 image 필드를 채워 넣는다. (fix_broken_questions.py는 원래 '깨진' 문항만 채웠으므로,
정상 텍스트가 있지만 그림도 있는 문항들은 PNG가 생성되어 있어도 image 필드가 비어 있었음.)
"""
import os, json

BASE = '/home/user/flutter_app/assets/data'
TRACKS = [
    'electrician', 'architecture', 'construction_safety', 'elec_industrial',
    'fire_electric', 'fire_mechanical', 'industrial_safety', 'info_processing',
    'elec_construction', 'hazmat_industrial',
]


def process_track(track):
    exams_path = os.path.join(BASE, track, 'exams.json')
    img_dir = os.path.join(BASE, track, 'images')
    if not os.path.exists(exams_path):
        return 0, 0, 0
    exams = json.load(open(exams_path, encoding='utf-8'))
    existing_files = set(os.listdir(img_dir)) if os.path.isdir(img_dir) else set()

    linked = 0
    already = 0
    missing = 0
    for e in exams:
        eid = e['id']
        for q in e['questions']:
            if not q.get('has_image'):
                continue
            if q.get('image'):
                already += 1
                continue
            fn = f'{eid}_{q["no"]:03d}.png'
            if fn in existing_files:
                q['image'] = f'images/{fn}'
                linked += 1
            else:
                missing += 1

    if linked:
        json.dump(exams, open(exams_path, 'w', encoding='utf-8'),
                   ensure_ascii=False, indent=2)
    return linked, already, missing


if __name__ == '__main__':
    grand_linked = grand_already = grand_missing = 0
    for t in TRACKS:
        l, a, m = process_track(t)
        print(f'[{t}] 신규 연결 {l}건 / 기존 연결 {a}건 / PNG 없음 {m}건')
        grand_linked += l
        grand_already += a
        grand_missing += m
    print(f'\n=== 합계: 신규 {grand_linked} / 기존 {grand_already} / 미해결(PNG 없음) {grand_missing} ===')
