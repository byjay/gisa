"""
comcbt.com 게시판 첨부파일(PDF) 일괄 다운로드 스크립트 v2.0
------------------------------------------------------
- 지정한 게시판(mid)의 모든 페이지를 순회하며 게시글 목록을 수집
- 각 게시글 페이지에서 첨부파일 다운로드 링크를 추출
- PDF(기본값) 또는 모든 첨부파일을 로컬 폴더에 저장

[v2.0 신규 기능] - 기존 v1 로직 전부 보존 + 확장
- 자격증 카탈로그 자동 수집: 사이트 전체 게시판(자격증) 목록 자동 추출 (600여개)
- 신설 자격증 감지: 이전 카탈로그와 비교하여 새로 추가된 게시판 탐지
- 이름 검색: 자격증 이름으로 게시판 id 검색
- CLI 인터페이스: 코드 수정 없이 명령행으로 모든 기능 사용

필요 패키지 설치:
    pip install requests beautifulsoup4

사용 예:
    # 1) 기본 실행 (v1 호환: nc, ku, ni 다운로드)
    python comcbt_downloader.py

    # 2) 원하는 게시판만 지정 다운로드
    python comcbt_downloader.py --boards kt iz nc

    # 3) 자격증 이름으로 검색 (게시판 id 찾기)
    python comcbt_downloader.py --search 전기기사

    # 4) 전체 자격증 카탈로그 갱신 + 목록 출력
    python comcbt_downloader.py --list

    # 5) 신설(새로 추가된) 자격증 감지 / 감지 후 즐시 다운로드
    python comcbt_downloader.py --detect-new
    python comcbt_downloader.py --download-new

    # 6) 이름으로 바로 다운로드 (부분일치)
    python comcbt_downloader.py --download-by-name 정보처리기사

    # 7) PDF 외 모든 첨부파일 포함 / 페이지 제한(테스트)
    python comcbt_downloader.py --boards nc --all-files --max-pages 2
"""

import os
import re
import sys
import json
import time
import argparse
import requests
from datetime import datetime
from bs4 import BeautifulSoup
from urllib.parse import urljoin, unquote

VERSION = "2.0"
CATALOG_FILE = "comcbt_catalog.json"  # 자격증 카탈로그 캐시 파일

BASE = "https://www.comcbt.com"
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    )
}


# ======================================================================
# [v2.0] 자격증 카탈로그 자동 수집 / 신설 자격증 감지 / 검색
# ======================================================================

def make_session():
    session = requests.Session()
    session.headers.update(HEADERS)
    return session


def fetch_board_catalog(session, seed_board="nc"):
    """사이트 메뉴에서 전체 게시판(자격증) id/이름 카탈로그를 자동 수집한다.

    comcbt는 모든 게시판 페이지에 전체 메뉴가 포함되므로,
    임의의 게시판 페이지 하나를 파싱하면 전체 목록을 얻을 수 있다.
    """
    url = f"{BASE}/xe/{seed_board}"
    resp = session.get(url, timeout=20)
    resp.raise_for_status()

    pairs = re.findall(
        r'href="(?:https?://www\.comcbt\.com)?/xe/([a-z]{1,6})"[^>]*>\s*(?:<[^>]+>)*([^<]{2,60})',
        resp.text,
    )
    catalog = {}
    for mid, name in pairs:
        name = name.strip()
        if mid and name and not name.startswith("&") and mid not in catalog:
            catalog[mid] = name
    return catalog


def load_catalog(path=CATALOG_FILE):
    """저장된 카탈로그 파일을 읽는다. 없으면 None."""
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    return None


def save_catalog(catalog, path=CATALOG_FILE):
    """카탈로그를 타임스탬프와 함께 저장한다."""
    data = {
        "updated_at": datetime.now().isoformat(timespec="seconds"),
        "version": VERSION,
        "boards": catalog,
    }
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    return path


def update_catalog(session, path=CATALOG_FILE, seed_board="nc"):
    """카탈로그를 갱신하고 (이전, 새 카탈로그, 추가분, 삭제분)을 반환한다."""
    old_data = load_catalog(path)
    old_boards = old_data["boards"] if old_data else {}

    new_boards = fetch_board_catalog(session, seed_board=seed_board)
    if not new_boards:
        raise RuntimeError("카탈로그 수집 실패: 메뉴를 찾지 못했습니다.")

    added = {mid: name for mid, name in new_boards.items() if mid not in old_boards}
    removed = {mid: name for mid, name in old_boards.items() if mid not in new_boards}

    save_catalog(new_boards, path)
    return old_boards, new_boards, added, removed


def detect_new_boards(session, path=CATALOG_FILE, seed_board="nc"):
    """신설 자격증(새 게시판) 감지. 첫 실행 시에는 기준 카탈로그만 저장한다."""
    first_run = not os.path.exists(path)
    old_boards, new_boards, added, removed = update_catalog(session, path, seed_board)

    if first_run:
        print(f"[카탈로그] 최초 수집 완료: 총 {len(new_boards)}개 게시판 저장 -> {path}")
        print("        다음 실행부터 신설 자격증을 감지합니다.")
        return {}

    if added:
        print(f"[신설 감지] 새로 추가된 게시판 {len(added)}개:")
        for mid, name in sorted(added.items()):
            print(f"  + {mid:6s} {name}")
    else:
        print("[신설 감지] 새로 추가된 게시판 없음")

    if removed:
        print(f"[참고] 사라진 게시판 {len(removed)}개:")
        for mid, name in sorted(removed.items()):
            print(f"  - {mid:6s} {name}")

    return added


def search_boards(keyword, catalog=None, session=None):
    """자격증 이름 부분일치 검색. (mid, name) 리스트 반환."""
    if catalog is None:
        data = load_catalog()
        if data:
            catalog = data["boards"]
        else:
            if session is None:
                session = make_session()
            catalog = fetch_board_catalog(session)
            save_catalog(catalog)
    keyword = keyword.strip().lower()
    return [(mid, name) for mid, name in catalog.items() if keyword in name.lower()]


# ======================================================================
# 기존 핵심 로직 (v1 그대로 유지)
# ======================================================================

def get_post_links(session, board, max_pages=None, delay=1.0):
    """게시판(mid)의 모든 게시글 상세 URL을 수집한다."""
    post_links = set()
    page = 1
    pattern = re.compile(rf"^/xe/{re.escape(board)}/\d+$")

    while True:
        url = f"{BASE}/xe/{board}" if page == 1 else f"{BASE}/xe/index.php?mid={board}&page={page}"
        resp = session.get(url, timeout=15)
        resp.raise_for_status()
        soup = BeautifulSoup(resp.text, "html.parser")

        found = set()
        for a in soup.select("a[href]"):
            href = a["href"]
            path = href[len(BASE):] if href.startswith(BASE) else href
            if pattern.match(path):
                found.add(BASE + path)

        if not found:
            break

        new_links = found - post_links
        post_links.update(found)
        print(f"[{board}] {page}페이지: 게시글 {len(found)}개 발견 (누적 {len(post_links)}개)")

        if max_pages and page >= max_pages:
            break
        if not new_links and page > 1:
            break

        page += 1
        time.sleep(delay)

    return sorted(post_links)


def get_download_links(session, post_url, pdf_only=True):
    """게시글 페이지에서 첨부파일 다운로드 링크(파일명, URL) 목록을 추출한다."""
    resp = session.get(post_url, timeout=15)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")

    links = []
    seen = set()
    for a in soup.select("a[href*='procFileDownload']"):
        href = a["href"]
        full_url = urljoin(BASE, href)
        if full_url in seen:
            continue
        filename = a.get_text(strip=True)
        if pdf_only and not filename.lower().endswith(".pdf"):
            continue
        seen.add(full_url)
        links.append((filename, full_url))
    return links


def sanitize_filename(name):
    return re.sub(r'[\\/:*?"<>|]', "_", name).strip()


def download_file(session, url, dest_path, delay=0.5):
    if os.path.exists(dest_path):
        print(f"    이미 존재함, 건너뜀: {os.path.basename(dest_path)}")
        return
    resp = session.get(url, timeout=30, stream=True)
    resp.raise_for_status()
    with open(dest_path, "wb") as f:
        for chunk in resp.iter_content(8192):
            f.write(chunk)
    print(f"    다운로드 완료: {os.path.basename(dest_path)}")
    time.sleep(delay)


def download_board(board, out_dir="comcbt_downloads", pdf_only=True, max_pages=None, delay=1.0, board_name=None):
    """게시판 하나를 통째로 다운로드한다.

    board_name이 주어지면 '자격증이름(id)' 형태의 폴더명을 사용한다. (v2.0)
    """
    session = make_session()

    folder = f"{sanitize_filename(board_name)}({board})" if board_name else board
    board_dir = os.path.join(out_dir, folder)
    os.makedirs(board_dir, exist_ok=True)

    post_links = get_post_links(session, board, max_pages=max_pages, delay=delay)
    print(f"\n=== [{board}] 총 {len(post_links)}개 게시글 처리 시작 ===\n")

    for i, post_url in enumerate(post_links, 1):
        print(f"[{i}/{len(post_links)}] {post_url}")
        try:
            files = get_download_links(session, post_url, pdf_only=pdf_only)
        except Exception as e:
            print(f"  게시글 처리 실패: {e}")
            continue

        if not files:
            print("  다운로드 가능한 파일 없음")
            continue

        for filename, url in files:
            filename = sanitize_filename(unquote(filename))
            if not filename:
                filename = url.split("file_srl=")[-1].split("&")[0] + ".pdf"
            dest_path = os.path.join(board_dir, filename)
            try:
                download_file(session, url, dest_path, delay=delay)
            except Exception as e:
                print(f"    다운로드 실패 ({filename}): {e}")

        time.sleep(delay)

    print(f"\n=== [{board}] 완료. 저장 위치: {os.path.abspath(board_dir)} ===\n")


# ======================================================================
# [v2.0] CLI 인터페이스
# ======================================================================

def resolve_board_names(boards, catalog):
    """게시판 id 목록에 대해 (id, 이름) 튜플 리스트를 반환한다."""
    return [(b, catalog.get(b)) for b in boards]


def main():
    parser = argparse.ArgumentParser(
        description=f"comcbt.com 기출문제 일괄 다운로더 v{VERSION}",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--boards", nargs="+", metavar="MID",
                        help="다운로드할 게시판 id 목록 (예: --boards nc ku kt)")
    parser.add_argument("--download-by-name", nargs="+", metavar="NAME",
                        help="자격증 이름(부분일치)으로 바로 다운로드")
    parser.add_argument("--search", metavar="KEYWORD",
                        help="자격증 이름으로 게시판 id 검색")
    parser.add_argument("--list", action="store_true",
                        help="전체 자격증 카탈로그 갱신 후 목록 출력")
    parser.add_argument("--detect-new", action="store_true",
                        help="신설(새로 추가된) 자격증 감지")
    parser.add_argument("--download-new", action="store_true",
                        help="신설 자격증 감지 후 즉시 다운로드까지 수행")
    parser.add_argument("--all-files", action="store_true",
                        help="PDF 외 모든 첨부파일(hwp 등)도 다운로드")
    parser.add_argument("--max-pages", type=int, default=None,
                        help="게시판당 최대 페이지 수 제한 (테스트용)")
    parser.add_argument("--delay", type=float, default=1.0,
                        help="요청 간 대기 시간(초), 기본 1.0")
    parser.add_argument("--out", default="comcbt_downloads",
                        help="저장 폴더 (기본: comcbt_downloads)")
    args = parser.parse_args()

    session = make_session()
    pdf_only = not args.all_files

    catalog_data = load_catalog()
    catalog = catalog_data["boards"] if catalog_data else {}

    if args.list:
        _, new_boards, added, _ = update_catalog(session)
        catalog = new_boards
        print(f"=== 전체 자격증 카탈로그 ({len(catalog)}개) ===")
        for mid, name in sorted(catalog.items(), key=lambda x: x[1]):
            print(f"  {mid:6s} {name}")
        if added:
            print(f"\n[신설] 이번 갱신에서 추가된 게시판 {len(added)}개:")
            for mid, name in sorted(added.items()):
                print(f"  + {mid:6s} {name}")
        return

    if args.search:
        results = search_boards(args.search, session=session)
        if results:
            print(f"=== '{args.search}' 검색 결과 ({len(results)}개) ===")
            for mid, name in results:
                print(f"  {mid:6s} {name}")
            print(f"\n다운로드 예: python {os.path.basename(sys.argv[0])} --boards " +
                  " ".join(mid for mid, _ in results[:3]))
        else:
            print(f"'{args.search}' 검색 결과 없음. --list 로 전체 목록을 확인하세요.")
        return

    if args.detect_new or args.download_new:
        added = detect_new_boards(session)
        if args.download_new and added:
            print(f"\n[신설 다운로드] {len(added)}개 게시판 다운로드 시작")
            for mid, name in sorted(added.items()):
                download_board(mid, out_dir=args.out, pdf_only=pdf_only,
                               max_pages=args.max_pages, delay=args.delay, board_name=name)
        return

    # --- 다운로드 대상 결정 ---
    targets = []  # (mid, name)

    if args.download_by_name:
        if not catalog:
            catalog = fetch_board_catalog(session)
            save_catalog(catalog)
        for kw in args.download_by_name:
            hits = search_boards(kw, catalog=catalog)
            if not hits:
                print(f"[경고] '{kw}' 에 해당하는 게시판 없음, 건너뜁")
                continue
            exact = [(m, n) for m, n in hits if n == kw]
            chosen = exact if exact else hits
            for m, n in chosen:
                print(f"[대상 추가] {m} {n}")
                targets.append((m, n))
    elif args.boards:
        if not catalog:
            try:
                catalog = fetch_board_catalog(session)
                save_catalog(catalog)
            except Exception:
                catalog = {}
        targets = resolve_board_names(args.boards, catalog)
    else:
        # 기본 동작(v1 호환): 기본 게시판 목록 다운로드
        default_boards = ["nc", "ku", "ni"]
        if not catalog:
            try:
                catalog = fetch_board_catalog(session)
                save_catalog(catalog)
            except Exception:
                catalog = {}
        targets = resolve_board_names(default_boards, catalog)

    if not targets:
        print("다운로드할 대상이 없습니다. --help 를 참고하세요.")
        return

    for mid, name in targets:
        download_board(mid, out_dir=args.out, pdf_only=pdf_only,
                       max_pages=args.max_pages, delay=args.delay, board_name=name)


if __name__ == "__main__":
    main()


# ---------------------------------------------------------------------
# [v1 호환 참고] 기존 방식 그대로 스크립트에서 쓰고 싶다면:
#   boards = ["nc", "ku", "ni"]
#   for b in boards:
#       download_board(b, out_dir="comcbt_downloads", pdf_only=True, delay=1.0)
#
# pdf_only=False 로 바꾸면 hwp 등 다른 첨부파일도 함께 받습니다.
# delay 값을 늘리면 서버에 부담을 덜 주고 차단 위험도 줄어듭니다.
# ---------------------------------------------------------------------
