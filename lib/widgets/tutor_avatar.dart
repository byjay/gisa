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

  /// true 면 얼굴(상단)만 원형으로 크롭해 작은 아이콘처럼 표시.
  /// 채팅 말풍선 옆 등 좁은 자리에서 사용(전신은 너무 얇아지므로).
  final bool headOnly;

  const TutorAvatar({
    super.key,
    this.mood = TutorMood.idle,
    this.size = 96,
    this.interval = const Duration(milliseconds: 2200),
    this.animate = true,
    this.headOnly = false,
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
    final errorIcon = Icon(
      Icons.face_retouching_natural,
      size: widget.size * 0.7,
      color: Colors.orange,
    );

    if (widget.headOnly) {
      // ⚠️ 크롭 금지(사용자 지시): 얼굴이 잘리지 않도록
      // 원형 배경 안에 "전신"을 contain 으로 온전히 담는다.
      final cs = Theme.of(context).colorScheme;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey(_asset),
          width: widget.size,
          height: widget.size,
          padding: EdgeInsets.all(widget.size * 0.08),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primaryContainer.withValues(alpha: 0.5),
          ),
          child: Image.asset(
            _asset,
            fit: BoxFit.contain, // 전신 그대로 — 잘림 없음
            errorBuilder: (_, __, ___) => errorIcon,
          ),
        ),
      );
    }

    // 튜터 원본 이미지는 세로가 긴 전신(≈132×292, 비율 0.45).
    // size 를 "높이" 기준으로 삼고, 폭은 비율에 맞춰 잡아 전신이 잘리지 않게 한다.
    const double aspect = 132 / 292; // 폭/높이
    final double h = widget.size;
    final double w = h * aspect;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: child,
      ),
      child: SizedBox(
        key: ValueKey(_asset),
        width: w,
        height: h,
        child: Image.asset(
          _asset,
          // contain: 이미지를 잘라내지 않고 전체가 보이도록 맞춤(#1)
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          errorBuilder: (_, __, ___) => errorIcon,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TutorAvatar(mood: mood, size: avatarSize),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('볼트쌤',
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
