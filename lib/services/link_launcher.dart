import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// 유튜브 링크를 "유튜브 앱"에서 우선 열도록 처리하는 공통 런처.
///
/// 동작 순서 (Android):
///   1) youtube.com / youtu.be 링크면 `vnd.youtube:` 딥링크로 유튜브 앱 직접 실행
///   2) 실패하면 일반 https 링크를 externalApplication 으로 실행
///      (안드로이드가 유튜브 앱 ↔ 브라우저 선택지를 제공)
/// 웹에서는 새 탭으로 열린다.
///
/// 성공하면 true, 모두 실패하면 false 를 반환한다(호출부에서 클립보드 폴백).
Future<bool> openInYoutubeApp(String url) async {
  final web = Uri.tryParse(url);
  if (web == null) return false;

  // 웹 플랫폼은 딥링크 스킴을 쓸 수 없으므로 바로 새 탭으로 연다.
  if (kIsWeb) {
    return _tryLaunch(web, LaunchMode.externalApplication);
  }

  // 1) 유튜브 딥링크 우선 시도 (모바일)
  final deep = _youtubeDeepLink(url);
  if (deep != null && await _tryLaunch(deep, LaunchMode.externalApplication)) {
    return true;
  }

  // 2) 일반 https 링크 → 유튜브 앱/브라우저 선택
  return _tryLaunch(web, LaunchMode.externalApplication);
}

/// 유튜브 URL을 `vnd.youtube:` 딥링크로 변환한다. 유튜브가 아니면 null.
Uri? _youtubeDeepLink(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return null;
  final host = u.host.toLowerCase();
  final isYoutube = host.contains('youtube.com') || host.contains('youtu.be');
  if (!isYoutube) return null;

  // 영상 ID 추출 (watch?v=, youtu.be/, /shorts/, /embed/)
  String? videoId;
  if (host.contains('youtu.be')) {
    videoId = u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
  } else {
    videoId = u.queryParameters['v'];
    if (videoId == null && u.pathSegments.length >= 2) {
      final seg = u.pathSegments;
      if (seg.first == 'shorts' || seg.first == 'embed') videoId = seg[1];
    }
  }

  if (videoId != null && videoId.isNotEmpty) {
    // vnd.youtube:<id> — 유튜브 앱이 곧바로 해당 영상을 연다.
    return Uri.parse('vnd.youtube:$videoId');
  }

  // 검색·채널·재생목록 등 영상 ID가 없는 링크는 vnd.youtube 로 원본 URL 전달
  // (유튜브 앱이 검색/채널 화면을 처리한다)
  return Uri.parse(
    'vnd.youtube://${u.host}${u.path}'
    '${u.hasQuery ? '?${u.query}' : ''}',
  );
}

Future<bool> _tryLaunch(Uri uri, LaunchMode mode) async {
  try {
    return await launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}
