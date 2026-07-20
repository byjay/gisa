import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

enum TutorMood { idle, happy, thinking, wrong, teaching, meditate, cheer }

/// 볼트쌤(푸티) 전용 — 상황(무드)별 포즈 프레임 매핑 (pose_01 ~ pose_38)
/// 스텝마다 다른 행동 이미지가 나오도록 각 무드에 여러 포즈를 배정한다.
const Map<TutorMood, List<int>> voltMoodPoses = {
  TutorMood.idle: [1, 7, 8, 11, 29, 6, 24],
  TutorMood.happy: [4, 16, 26, 34, 30, 19, 38],
  TutorMood.thinking: [5, 9, 12, 17, 27, 22, 23],
  TutorMood.wrong: [10, 11, 28, 37, 20],
  TutorMood.teaching: [2, 3, 13, 14, 21, 18, 32],
  TutorMood.meditate: [35, 36, 31],
  TutorMood.cheer: [4, 15, 25, 33, 34, 19, 38],
};

String voltPoseAsset(int pose) =>
    'assets/tutor/pose_${pose.toString().padLeft(2, '0')}.png';

/// 정적 강사(소연·하린·지윤)의 무드별 시각 반응 — 배지 이모지.
/// 포즈 이미지가 없는 강사도 상황마다 다른 리액션이 보이게 한다.
const Map<TutorMood, String> moodBadge = {
  TutorMood.idle: '',
  TutorMood.happy: '🎉',
  TutorMood.thinking: '🤔',
  TutorMood.wrong: '💦',
  TutorMood.teaching: '📖',
  TutorMood.meditate: '🧘',
  TutorMood.cheer: '📣',
};

/// 정적 강사의 무드별 기울기(라디안) — 살아있는 느낌의 미세 모션.
const Map<TutorMood, double> _moodTilt = {
  TutorMood.idle: 0.0,
  TutorMood.happy: 0.05,
  TutorMood.thinking: -0.06,
  TutorMood.wrong: -0.04,
  TutorMood.teaching: 0.03,
  TutorMood.meditate: 0.0,
  TutorMood.cheer: 0.06,
};

class TutorProfile {
  final String id;
  final String name;
  final String role;
  final String asset;

  /// 선생님별 고유 시그니처 컬러 — 말풍선/배지/강조색에 사용해
  /// 어느 선생님이 말하고 있는지 한눈에 구분되게 한다.
  final Color color;

  /// 지도 스타일 태그 (예: '차분한 이론파')
  final String styleTag;

  /// 대표 이모지
  final String emoji;

  /// true면 포즈 애니메이션 캐릭터(볼트쌤) — pose_01~38 프레임 사용
  final bool animatedPoses;

  const TutorProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.asset,
    required this.color,
    required this.styleTag,
    required this.emoji,
    this.animatedPoses = false,
  });
}

/// 🎓 선생님 4인 체제 — 볼트쌤(푸티) + 소연 + 하린 + 지윤
const tutorProfiles = <TutorProfile>[
  TutorProfile(
    id: 'volt',
    name: '볼트쌤',
    role: '반복 암기와 시험 함정을 잡는 총괄 튜터 (38가지 행동 포즈)',
    asset: 'assets/tutor/pose_01.png',
    color: Color(0xFFF59E0B), // 에너지 앰버
    styleTag: '열정 총괄 코치',
    emoji: '⚡',
    animatedPoses: true,
  ),
  TutorProfile(
    id: 'soyeon',
    name: '소연 선생님',
    role: '개념과 공식을 차분하게 연결하는 이론 강사',
    asset: 'assets/tutor/teacher_soyeon.png',
    color: Color(0xFF2E7DFF), // 차분한 블루
    styleTag: '차분한 이론파',
    emoji: '📘',
  ),
  TutorProfile(
    id: 'harin',
    name: '하린 선생님',
    role: '문제·정답을 빠르게 각인시키는 암기 코치',
    asset: 'assets/tutor/teacher_harin.png',
    color: Color(0xFFFF6B35), // 스피드 오렌지
    styleTag: '속전속결 암기코치',
    emoji: '🔥',
  ),
  TutorProfile(
    id: 'jiyoon',
    name: '지윤 선생님',
    role: '심화 이론과 실기 적용을 짚어주는 전문 강사',
    asset: 'assets/tutor/teacher_jiyoon.png',
    color: Color(0xFF7C4DFF), // 전문가 퍼플
    styleTag: '실전 심화 전문가',
    emoji: '🎯',
  ),
];

TutorProfile tutorProfileById(String id) => tutorProfiles.firstWhere(
  (profile) => profile.id == id,
  orElse: () => tutorProfiles.first,
);

/// 사용자가 고른 강사 이미지를 원본 비율로 표시한다.
/// 볼트쌤은 무드별 38개 포즈를 순환하는 살아있는 애니메이션으로,
/// 정적 강사(소연·하린·지윤)는 전신 이미지 그대로 표시한다.
class TutorAvatar extends StatefulWidget {
  final TutorMood mood;
  final double size;
  final Duration interval;
  final bool animate;
  final String characterId;
  final bool rotate;
  final bool headOnly;

  /// 볼트쌤 전용 — 특정 포즈를 고정 표시(상황별 지정 포즈)
  final int? poseOverride;

  const TutorAvatar({
    super.key,
    this.mood = TutorMood.idle,
    this.size = 96,
    this.interval = const Duration(milliseconds: 2200),
    this.animate = true,
    this.headOnly = false,
    this.characterId = 'selected',
    this.rotate = true,
    this.poseOverride,
  });

  @override
  State<TutorAvatar> createState() => _TutorAvatarState();
}

class _TutorAvatarState extends State<TutorAvatar> {
  Timer? _timer;
  int _frameIdx = 0;
  final _rand = Random();

  List<int> get _frames =>
      voltMoodPoses[widget.mood] ?? voltMoodPoses[TutorMood.idle]!;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(TutorAvatar old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood || old.animate != widget.animate) {
      _frameIdx = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (!widget.animate || widget.poseOverride != null) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() {
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

  String _voltAsset() {
    if (widget.poseOverride != null) {
      return voltPoseAsset(widget.poseOverride!.clamp(1, 38));
    }
    final pose = _frames[_frameIdx % _frames.length];
    return voltPoseAsset(pose);
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.characterId == 'selected'
        ? context.select<AppProvider, String>((app) => app.selectedTutorId)
        : widget.characterId;
    final profile = tutorProfileById(selectedId);
    final cs = Theme.of(context).colorScheme;

    // 볼트쌤이면 무드별 포즈 프레임, 아니면 고정 전신 이미지 + 무드 리액션
    final asset = profile.animatedPoses ? _voltAsset() : profile.asset;
    final headOnly = widget.headOnly;
    // 이미지 실측 비율: pose 프레임 132×292(0.452), teacher 1536×2752(0.558).
    // 비율 + 기울기 여유분을 더해 어떤 상황에서도 잘리지 않게 한다.
    final ratio = profile.animatedPoses ? 0.46 : 0.56;
    final width = headOnly ? widget.size : widget.size * (ratio + 0.08);
    final badge = profile.animatedPoses ? '' : (moodBadge[widget.mood] ?? '');
    final tilt = profile.animatedPoses ? 0.0 : (_moodTilt[widget.mood] ?? 0.0);

    Widget image = Image.asset(
      asset,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Icon(
        Icons.person_rounded,
        size: widget.size * 0.65,
        color: cs.primary,
      ),
    );
    // 정적 강사는 무드에 따라 미세 기울기 — 살아있는 느낌.
    // 하단 중심축 회전 + 축소로 회전해도 경계 밖으로 밀려나 잘리지 않게 한다.
    if (tilt != 0.0) {
      image = AnimatedRotation(
        turns: tilt / (2 * pi),
        alignment: Alignment.bottomCenter,
        duration: const Duration(milliseconds: 400),
        child: image,
      );
    }
    // 무드 리액션 배지 (정적 강사 전용)
    if (badge.isNotEmpty && !headOnly) {
      image = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: image),
          Positioned(
            top: 0,
            right: -2,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                badge,
                key: ValueKey(badge),
                style: TextStyle(fontSize: widget.size * 0.2),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      image: true,
      label: '${profile.name} 캐릭터',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        // 전환 중 old/new 프레임이 겹칠 때 어긋난 중복 조각이 보이지 않도록
        // 하단 중앙 정렬 스택으로 고정한다.
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        child: Container(
          // 정적 강사는 이미지가 바뀌지 않으므로 asset만 key로 사용 —
          // mood 변경 때 같은 이미지 2장이 겹쳐 보이던 중복 버그 제거.
          key: ValueKey(asset),
          width: width,
          height: widget.size,
          padding: EdgeInsets.all(headOnly ? widget.size * 0.05 : 0),
          decoration: headOnly
              ? BoxDecoration(
                  color: profile.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(widget.size * 0.26),
                )
              : null,
          child: image,
        ),
      ),
    );
  }
}

/// 말풍선 포함 강사 배너 — 홈/슬라이드 화면용.
/// 선생님별 시그니처 컬러가 배경·이름에 반영된다.
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
    final tutorId = context.select<AppProvider, String>(
      (app) => app.selectedTutorId,
    );
    final tutor = tutorProfileById(tutorId);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tutor.color.withValues(alpha: 0.16),
              cs.secondaryContainer.withValues(alpha: 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tutor.color.withValues(alpha: 0.3)),
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
                      Text(
                        '${tutor.emoji} ${tutor.name}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: tutor.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: tutor.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tutor.styleTag,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: tutor.color,
                          ),
                        ),
                      ),
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
              Icon(
                Icons.chevron_right,
                color: tutor.color.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }
}
