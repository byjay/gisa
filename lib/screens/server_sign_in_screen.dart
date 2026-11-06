import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../services/app_config.dart';
import '../services/auth_service.dart';
import '../services/remote_content_api.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// 원격 콘텐츠 모드에서 API 데이터 접근 전 계정을 확인한다.
class ServerSignInScreen extends StatefulWidget {
  const ServerSignInScreen({super.key});

  @override
  State<ServerSignInScreen> createState() => _ServerSignInScreenState();
}

class _ServerSignInScreenState extends State<ServerSignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() => _runSignIn((auth) => auth.signInWithGoogle());

  Future<void> _signInWithKakao() =>
      _runSignIn((auth) => auth.signInWithKakao());

  Future<void> _runSignIn(
    Future<UserProfile> Function(AuthService auth) signIn,
  ) async {
    final auth = context.read<AuthService>();
    final app = context.read<AppProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await signIn(auth);
      if (!mounted) return;
      RemoteContentApi.instance.authToken = auth.sessionToken;
      await app.initSchedule();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('cancel') || message.contains('canceled')) {
      return '로그인을 취소했어요. 원할 때 다시 시도해 주세요.';
    }
    if (message.contains('timeout') ||
        message.contains('socketexception') ||
        message.contains('network')) {
      return '인터넷 연결을 확인하고 다시 시도해 주세요.';
    }
    return '로그인에 실패했어요. 잠시 후 다시 시도해 주세요.';
  }

  @override
  Widget build(BuildContext context) {
    final googleConfigured =
        AppConfig.hasApi && AppConfig.googleOAuthClientId.isNotEmpty;
    final kakaoConfigured =
        AppConfig.hasApi && !kIsWeb && AppConfig.kakaoNativeAppKey.isNotEmpty;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 0,
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.96),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Image.asset(
                            'assets/brand/logo_square_512.png',
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            semanticLabel: '기사클럽 로고',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '기사클럽',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '자격증별 공부와 오답 복습을 시작해요',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                height: 1.4,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (kakaoConfigured)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _loading ? null : _signInWithKakao,
                              icon: _loading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                    ),
                              label: Text(_loading ? '로그인 중…' : '카카오로 계속'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFEE500),
                                foregroundColor: const Color(0xFF191919),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        if (googleConfigured && kakaoConfigured)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('또는'),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                          ),
                        if (googleConfigured)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _loading ? null : _signIn,
                              icon: _loading
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.account_circle_rounded),
                              label: Text(_loading ? '로그인 중…' : 'Google로 계속'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        if (!AppConfig.hasApi ||
                            (!googleConfigured && !kakaoConfigured)) ...[
                          const SizedBox(height: 16),
                          Text(
                            !AppConfig.hasApi
                                ? '간편 로그인을 준비하고 있어요. 서비스 연결이 완료되면 로그인 버튼이 표시됩니다.'
                                : kIsWeb
                                ? '웹 간편 로그인은 준비 중입니다. 모바일 앱에서 로그인을 이용해 주세요.'
                                : '간편 로그인 연결을 준비하고 있어요. 잠시 후 다시 확인해 주세요.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  height: 1.5,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
