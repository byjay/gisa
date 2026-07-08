import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

/// 튜터 감정/상황 상태
enum TutorMood {
  idle, // 대기 (인사·자연스러운 동작)
  happy, // 정답·칭찬
  thinking, // 고민중·문제 풀이중
  wrong, // 오답·아쉬움
  teaching, // 설명중 (칠판·책)
  meditate, // 집중·휴식
  cheer, // 응원·화이팅
}

/// 상황별 포즈 프레임 매핑 (pose_01 ~ pose_38)
const Map<TutorMood, List<int>> _moodPoses = {
  TutorMood.idle: [1, 7, 8, 11, 29],
  TutorMood.happy: [4, 16, 26, 34, 30],
  TutorMood.thinking: [5, 9, 12, 17, 27],
  TutorMood.wrong: [10, 11, 28, 37],
  TutorMood.teaching: [2, 3, 13, 14, 21],
  TutorMood.meditate: [35, 36, 31],
  TutorMood.cheer: [4, 15, 25, 33, 34],
};

/// 애니메이션 튜터 아바타 — 포즈 프레임을 부드럽게 전환
class TutorAvatar extends StatefulWidget {
  final TutorMood mood;
  final double size;
  final Duration interval;
  final bool animate;

  const TutorAvatar({
    super.key,
    this.mood = TutorMood.idle,
    this.size = 96,
    this.interval = const Duration(milliseconds: 2200),
    this.animate = true,
  });

  @override
  State<TutorAvatar> createState() => _TutorAvatarState();
}

class _TutorAvatarState extends State<TutorAvatar> {
  Timer? _timer;
  int _frameIdx = 0;
  final _rand = Random();

  List<int> get _frames => _moodPoses[widget.mood] ?? _moodPoses[TutorMood.idle]!;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(TutorAvatar old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _frameIdx = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.animate) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() {
        // 다음 프레임 (같은 프레임 반복 방지)
        if (_frames.length > 1) {
          int next;
          do {
            next = _rand.nextInt(_frames.length);
          } while (next == _frameIdx);
          _frameIdx = next;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _asset {
    final pose = _frames[_frameIdx % _frames.length];
    return 'assets/tutor/pose_${pose.toString().padLeft(2, '0')}.png';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(anim),
          child: child,
        ),
      ),
      child: ClipRRect(
        key: ValueKey(_asset),
        borderRadius: BorderRadius.circular(widget.size * 0.18),
        child: Image.asset(
          _asset,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.55),
          errorBuilder: (_, __, ___) => Icon(
            Icons.face_retouching_natural,
            size: widget.size * 0.7,
            color: Colors.orange,
          ),
        ),
      ),
    );
  }
}

/// 말풍선 포함 튜터 배너 — 홈/슬라이드 화면용
class TutorBanner extends StatelessWidget {
  final TutorMood mood;
  final String message;
  final double avatarSize;
  final VoidCallback? onTap;

  const TutorBanner({
    super.key,
    this.mood = TutorMood.idle,
    required this.message,
    this.avatarSize = 72,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withValues(alpha: 0.85),
              cs.secondaryContainer.withValues(alpha: 0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            TutorAvatar(mood: mood, size: avatarSize),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('푸키 튜터',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: cs.primary,
                          )),
                      const SizedBox(width: 4),
                      const Text('🎓', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 13.5, height: 1.35),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, color: cs.primary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
