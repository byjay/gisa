import 'package:flutter/material.dart';
import '../../services/kimi_service.dart';
import '../../services/study_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tutor_avatar.dart';

/// AI 튜터 채팅 — Kimi K2(Moonshot) 기반. 항상 최신정보·학습가이드 제공.
class TutorChatScreen extends StatefulWidget {
  const TutorChatScreen({super.key});

  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends State<TutorChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatTurn> _turns = [];
  bool _loading = false;
  bool _hasKey = false;

  // 추천 질문 (학습가이드 튜터 성격 강조)
  List<String> get _suggestions {
    final t = StudyData.instance.track.name;
    return [
      '$t 비전공자 공부 순서 알려줘',
      '가장 어려운 과목과 공략법은?',
      '시험 D-30 학습 계획 짜줘',
      '실기에서 자주 나오는 주제는?',
    ];
  }

  @override
  void initState() {
    super.initState();
    KimiService.instance.hasKey().then((v) {
      if (mounted) setState(() => _hasKey = v);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _loading) return;

    if (!await KimiService.instance.hasKey()) {
      if (!mounted) return;
      await _showKeyDialog();
      if (!await KimiService.instance.hasKey()) return;
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _turns.add(ChatTurn('user', msg));
      _loading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final answer = await KimiService.instance.chat(_turns);
      if (!mounted) return;
      setState(() {
        _turns.add(ChatTurn('assistant', answer));
        _loading = false;
        _hasKey = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _turns.add(ChatTurn('assistant', '⚠️ ${e.toString()}'));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showKeyDialog() async {
    final keyCtrl = TextEditingController(
        text: await KimiService.instance.getApiKey() ?? '');
    final modelCtrl = TextEditingController(
        text: await KimiService.instance.getModel());
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kimi(Moonshot) API 키 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI 튜터를 쓰려면 Kimi(Moonshot) API 키가 필요해요.\n'
                '1. platform.moonshot.ai 접속 → 로그인\n'
                '2. API Keys 메뉴에서 키 생성 (sk-...)\n'
                '3. 아래에 붙여넣기 (기기에만 저장됩니다)',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key (sk-...)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: modelCtrl,
                decoration: const InputDecoration(
                  labelText: '모델명',
                  hintText: 'kimi-k2.6',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '모델은 kimi-k2.6 (기본) 또는 kimi-k2.6-thinking 사용 가능.',
                style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () async {
              await KimiService.instance.setApiKey(keyCtrl.text);
              await KimiService.instance.setModel(modelCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                final has = await KimiService.instance.hasKey();
                setState(() => _hasKey = has);
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_rounded, size: 22),
            SizedBox(width: 8),
            Text('AI 튜터 (Kimi)'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'API 키 설정',
            icon: Icon(
                _hasKey ? Icons.vpn_key_rounded : Icons.vpn_key_off_rounded,
                color: _hasKey ? Colors.teal : null),
            onPressed: _showKeyDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _turns.isEmpty
                  ? _emptyState(cs)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      itemCount: _turns.length + (_loading ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= _turns.length) return _typingBubble(cs);
                        return _bubble(_turns[i], cs);
                      },
                    ),
            ),
            _inputBar(cs),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme cs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      children: [
        const Center(child: TutorAvatar(mood: TutorMood.teaching, size: 120)),
        const SizedBox(height: 14),
        Text(
          '무엇이든 물어보세요!\nKimi AI 튜터가 최신 시험정보와\n학습가이드를 알려드립니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 14.5,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.75)),
        ),
        const SizedBox(height: 22),
        Text('추천 질문',
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: cs.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 10),
        ..._suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _send(s),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 17, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(s,
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600)),
                        ),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: cs.primary),
                      ],
                    ),
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _bubble(ChatTurn turn, ColorScheme cs) {
    final isUser = turn.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const TutorAvatar(mood: TutorMood.happy, size: 34, animate: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: isUser
                    ? cs.primary
                    : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: SelectableText(
                turn.content,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: isUser ? Colors.white : cs.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingBubble(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const TutorAvatar(mood: TutorMood.thinking, size: 34),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: '질문을 입력하세요…',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _loading ? null : () => _send(_controller.text),
            elevation: 0,
            backgroundColor: _loading ? cs.surfaceContainerHighest : cs.primary,
            child: Icon(Icons.send_rounded,
                color: _loading ? cs.onSurface.withValues(alpha: 0.4) : Colors.white),
          ),
        ],
      ),
    );
  }
}
