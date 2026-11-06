import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/exam_track.dart';
import '../theme/app_theme.dart';
import '../widgets/tutor_avatar.dart';

/// 시험 종목 선택 — 검색과 종목별 색상 카드로 자격증을 고른다.
class TrackSelectScreen extends StatefulWidget {
  const TrackSelectScreen({super.key});

  @override
  State<TrackSelectScreen> createState() => _TrackSelectScreenState();
}

class _TrackSelectScreenState extends State<TrackSelectScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final query = _query.trim().toLowerCase();
    final tracks = kExamTracks.where((track) {
      if (query.isEmpty) return true;
      return '${track.name} ${track.tagline} ${track.subjects.join(' ')}'
          .toLowerCase()
          .contains(query);
    }).toList();
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, cons) {
            final wide = cons.maxWidth > 720;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const TutorAvatar(
                      mood: TutorMood.cheer,
                      size: 68,
                      characterId: 'volt',
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '어떤 시험을 준비하세요?',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: dark ? Colors.white : AppTheme.textStrong,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '기출·이론·암기법·모의고사까지 합격에 필요한 모든 것을 한 앱에서. 제가 끝까지 도와드릴게요! ⚡',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: dark ? Colors.white70 : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  textInputAction: TextInputAction.search,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    hintText: '자격증 또는 과목 검색',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '검색어 지우기',
                            onPressed: () => setState(() => _query = ''),
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: dark ? const Color(0xFF202536) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(
                      alpha: dark ? 0.18 : 0.08,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${kExamTracks.length}개 자격 종목 · ${kExamTracks.fold<int>(0, (sum, track) => sum + track.subjects.length)}개 전 과목 학습 지원',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : AppTheme.textStrong,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (tracks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 42,
                          color: dark ? Colors.white54 : AppTheme.textMuted,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '검색 결과가 없어요',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : AppTheme.textStrong,
                          ),
                        ),
                        Text(
                          '자격증 이름이나 과목을 다시 확인해 주세요.',
                          style: TextStyle(
                            color: dark ? Colors.white60 : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final t in tracks) ...[
                    _TrackButton(track: t),
                    const SizedBox(height: 14),
                  ],
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '선택은 나중에 홈에서 언제든 바꿀 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: dark ? Colors.white38 : AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: wide
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: content,
                      ),
                    )
                  : content,
            );
          },
        ),
      ),
    );
  }
}

class _TrackButton extends StatelessWidget {
  final ExamTrack track;
  const _TrackButton({required this.track});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [track.color, track.accent],
          stops: const [0.0, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        boxShadow: AppTheme.glowShadow(track.color),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.rLg),
          onTap: () => context.read<AppProvider>().selectTrack(track.id),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(track.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${track.emoji} ${track.name}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.tagline,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${track.subjects.length}개 전 과목 · 기출 ${track.questionCountLabel}문항 · 강의 ${track.topicCount}토픽 · 실기·암기카드',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
