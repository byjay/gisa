import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'admin/admin_console_screen.dart';
import 'services/admin_service.dart';
import 'services/app_config.dart';
import 'services/crash_logger.dart';
import 'theme/app_theme.dart';

/// 🛠️ 관리자 전용 앱 엔트리포인트 (R59).
///
/// 학습앱(main.dart)과 **동일 코드베이스**를 공유하되, 이 엔트리로 빌드하면
/// 학습 UI 없이 곧장 [관리자 콘솔]로 진입한다(배민의 "관리자 백오피스" 대응).
///
/// [빌드 방법]
///   flutter build apk --release \
///     -t lib/main_admin.dart \
///     --flavor admin \
///     --dart-define=API_BASE_URL=`https://WORKER.workers.dev` \
///     --dart-define=WEB_BASE_URL=`https://PAGES.pages.dev`
///
/// [인증] 앱 내부에 관리자 비밀은 없다. 대시보드(Cloudflare Access)에서 발급받은
///        토큰을 등록하면 Worker가 `/v1/admin/verify`로 최종 판정한다(R57 구조 재사용).
Future<void> main() async {
  runZonedGuarded(_bootstrap, (error, stack) {
    unawaited(
      CrashLogger.instance.record(error.toString(), stack: stack.toString()),
    );
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CrashLogger.instance.init();
  await initializeDateFormatting('ko');
  // 관리자 세션(저장된 토큰) 복원 + 온라인이면 서버 재검증.
  await AdminService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: AdminService.instance),
      ],
      child: const AdminApp(),
    ),
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.paletteById('indigo');
    return MaterialApp(
      title: 'Gisaclub 관리자',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      home: const _AdminRootBanner(child: AdminConsoleScreen()),
    );
  }
}

/// 관리자 빌드임을 시각적으로 명확히 하기 위한 상단 배너(운영 실수 방지).
class _AdminRootBanner extends StatelessWidget {
  const _AdminRootBanner({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: AppConfig.hasApi ? 'ADMIN' : 'ADMIN · NO API',
      location: BannerLocation.topStart,
      color: AppTheme.danger,
      child: child,
    );
  }
}
