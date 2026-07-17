import 'package:flutter/material.dart';
import '../../services/cerebras_service.dart';
import '../../services/study_data.dart';
import '../../services/tutor_persona.dart';
import '../../services/tutor_speech_service.dart';
import '../../widgets/tutor_avatar.dart';

/// AI 튜터 채팅 — Cerebras gpt-oss-120b 기반 "생각하는 튜터".
/// 답변 전에 모델이 단계별 추론(thinking)을 수행하고,
/// 사용자는 '🧠 생각 과정' 을 펼쳐서 볼 수 있다.
class TutorChatScreen extends StatefulWidget {
  const TutorChatScreen({super.key});

  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

/// 화면용 메시지 — 생각 과정 포함
class _Msg {
  final String role; // 'user' | 'assistant'
  final String content;
  final String thinking;
  bool showThinking = false; // 사용자가 '생각 과정'을 펼치면 true
  _Msg(this.role, this.content, {this.thinking = ''});
}

class _TutorChatScreenState extends State<TutorChatScreen> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _msgs = [];
  bool _loading = false;
  bool _speakerOn = true;
  String _effort = 'medium'; // 사고 깊이
  TutorPersona _persona = kTutorPersonas.first;

  @override
  void initState() {
    super.initState();
    TutorPersonaStore.load().then((p) {
      if (mounted) setState(() => _persona = p);
    });
  }

  List<String> get _suggestions {
    final t = StudyData.instance.track.name;
    // 페르소나 전용 추천 질문 + 종목 공통 질문 1개
    return [..._persona.suggestions, '$t 시험의 합격 기준이 어떻게 돼?'];
  }

  Future<void> _pickPersona() async {
    final picked = await showModalBottomSheet<TutorPersona>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              '튜터 선생님 선택',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '나의 수준과 취향에 맞는 선생님을 골라보세요',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(
                  ctx,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 12),
            ...kTutorPersonas.map((p) {
              final selected = p.id == _persona.id;
              final cs = Theme.of(ctx).colorScheme;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? cs.primaryContainer.withValues(alpha: 0.6)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(ctx, p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(p.emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  p.tagline,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: cs.primary,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      await TutorPersonaStore.save(picked.id);
      setState(() {
        _persona = picked;
        // 새 선생님 소개 메시지 (대화 이력은 유지)
        _msgs.add(
          _Msg(
            'assistant',
            '${picked.emoji} 안녕하세요! 지금부터 『${picked.name}』이 함께할게요. ${picked.tagline}',
          ),
        );
      });
      _scrollToBottom();
    }
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

    FocusScope.of(context).unfocus();
    final hasKey = await CerebrasService.instance.hasKey();
    if (!mounted) return;
    if (!hasKey) {
      setState(() {
        _msgs.add(_Msg('user', msg));
        _msgs.add(
          _Msg(
            'assistant',
            'AI 키가 아직 설정되지 않았어요. 우측 상단의 열쇠 버튼에서 본인 키를 설정하거나, 학습 메뉴의 이론 검색에서 로컬 강의·공식·암기법을 바로 찾아보세요.',
          ),
        );
        _controller.clear();
      });
      _scrollToBottom();
      return;
    }
    setState(() {
      _msgs.add(_Msg('user', msg));
      _loading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final history = _msgs
          .map((m) => TutorTurn(m.role, m.content))
          .toList(growable: false);
      final reply = await CerebrasService.instance.chat(
        history,
        effort: _effort,
        personaStyle: _persona.stylePrompt,
      );
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg('assistant', reply.answer, thinking: reply.thinking));
        _loading = false;
      });
      if (_speakerOn) {
        await TutorSpeechService.instance.speak(
          reply.answer,
          rate: _persona.speechRate,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg('assistant', '⚠️ ${e.toString()}'));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 160,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showSettings() async {
    final keyCtrl = TextEditingController(
      text: await CerebrasService.instance.getApiKey(),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('볼트쌤 튜터 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cerebras 추론 엔진(gpt-oss-120b)을 사용합니다.\n'
                '보안을 위해 앱에는 공용 키를 넣지 않습니다.\n'
                '본인이 발급한 키를 입력하면 이 기기에만 저장됩니다.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key (csk-...)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () async {
              await CerebrasService.instance.setApiKey(keyCtrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
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
        title: Row(
          children: [
            Text(_persona.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(_persona.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _speakerOn ? '자동 음성 끄기' : '자동 음성 켜기',
            icon: Icon(
              _speakerOn ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            ),
            onPressed: () {
              setState(() => _speakerOn = !_speakerOn);
              if (!_speakerOn) TutorSpeechService.instance.stop();
            },
          ),
          IconButton(
            tooltip: '튜터 선생님 변경',
            icon: const Icon(Icons.switch_account_rounded),
            onPressed: _pickPersona,
          ),
          // 사고 깊이 선택
          PopupMenuButton<String>(
            tooltip: '사고 깊이',
            icon: const Icon(Icons.tune_rounded),
            initialValue: _effort,
            onSelected: (v) => setState(() => _effort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'low', child: Text('⚡ 빠른 생각 (low)')),
              PopupMenuItem(value: 'medium', child: Text('🧠 보통 생각 (medium)')),
              PopupMenuItem(value: 'high', child: Text('🔬 깊은 생각 (high)')),
            ],
          ),
          IconButton(
            tooltip: 'API 키 설정',
            icon: const Icon(Icons.vpn_key_rounded, color: Colors.teal),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _msgs.isEmpty
                  ? _emptyState(cs)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      itemCount: _msgs.length + (_loading ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i >= _msgs.length) return _thinkingBubble(cs);
                        return _bubble(_msgs[i], cs);
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
        Center(
          child: TutorAvatar(
            mood: TutorMood.teaching,
            size: 120,
            characterId: _persona.characterId,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _pickPersona,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_persona.emoji} ${_persona.name}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more_rounded, size: 17, color: cs.primary),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_persona.tagline}\n답변은 학습 참고용이며, 중요한 법규·수치는\n앱의 최신 시험정보와 함께 확인하세요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.6,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
            ),
            child: const Text(
              '🧠 Cerebras 초고속 추론 · 답변마다 생각 과정 확인 가능',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.teal,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '추천 질문',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 10),
        ..._suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _send(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 17,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(_Msg m, ColorScheme cs) {
    final isUser = m.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            TutorAvatar(
              mood: TutorMood.happy,
              size: 34,
              animate: false,
              headOnly: true,
              characterId: _persona.characterId,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // 🧠 생각 과정 (접기/펼치기)
                if (!isUser && m.thinking.isNotEmpty) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () =>
                        setState(() => m.showThinking = !m.showThinking),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🧠', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 5),
                          Text(
                            m.showThinking ? '생각 과정 접기' : '생각 과정 보기',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.deepPurple,
                            ),
                          ),
                          Icon(
                            m.showThinking
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 16,
                            color: Colors.deepPurple,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (m.showThinking)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.18),
                        ),
                      ),
                      child: SelectableText(
                        m.thinking,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.55,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
                if (!isUser)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '튜터 답변 듣기',
                      icon: const Icon(Icons.volume_up_rounded, size: 19),
                      onPressed: () => TutorSpeechService.instance.speak(
                        m.content,
                        rate: _persona.speechRate,
                      ),
                    ),
                  ),
                Container(
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
                    m.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: isUser ? Colors.white : cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thinkingBubble(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          TutorAvatar(
            mood: TutorMood.thinking,
            size: 34,
            headOnly: true,
            characterId: _persona.characterId,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  '🧠 생각하는 중…',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            onPressed: _loading ? null : () => _send(_controller.text),
            elevation: 0,
            backgroundColor: _loading ? cs.surfaceContainerHighest : cs.primary,
            child: Icon(
              Icons.send_rounded,
              color: _loading
                  ? cs.onSurface.withValues(alpha: 0.4)
                  : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
