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

/// 소연·하린·지윤 3D 강사 전용 — 무드별 포즈 프레임 매핑 (pose_01 ~ pose_50)
/// 시트 구성: 1-10 idle, 11-20 happy, 21-30 thinking, 31-40 teaching,
/// 41-44 wrong, 45-48 cheer, 49-50 meditate.
const Map<TutorMood, List<int>> teacherMoodPoses = {
  TutorMood.idle: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  TutorMood.happy: [11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
  TutorMood.thinking: [21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
  TutorMood.teaching: [31, 32, 33, 34, 35, 36, 37, 38, 39, 40],
  TutorMood.wrong: [41, 42, 43, 44],
  TutorMood.cheer: [45, 46, 47, 48, 16, 20],
  TutorMood.meditate: [49, 50],
};

String teacherPoseAsset(String tutorId, int pose) =>
    'assets/tutor/${tutorId}_pose_${pose.toString().padLeft(2, '0')}.png';

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

  /// true면 포즈 애니메이션 캐릭터 — 볼트쌤 pose_01~38 / 강사 {id}_pose_01~50 프레임 사용
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
    role: '개념과 공식을 차분하게 연결하는 이론 강사 (50가지 3D 포즈)',
    asset: 'assets/tutor/soyeon_pose_01.png',
    color: Color(0xFF2E7DFF), // 차분한 블루
    styleTag: '차분한 이론파',
    emoji: '📘',
    animatedPoses: true,
  ),
  TutorProfile(
    id: 'harin',
    name: '하린 선생님',
    role: '문제·정답을 빠르게 각인시키는 암기 코치 (50가지 3D 포즈)',
    asset: 'assets/tutor/harin_pose_01.png',
    color: Color(0xFFFF6B35), // 스피드 오렌지
    styleTag: '속전속결 암기코치',
    emoji: '🔥',
    animatedPoses: true,
  ),
  TutorProfile(
    id: 'jiyoon',
    name: '지윤 선생님',
    role: '심화 이론과 실기 적용을 짚어주는 전문 강사 (50가지 3D 포즈)',
    asset: 'assets/tutor/jiyoon_pose_01.png',
    color: Color(0xFF7C4DFF), // 전문가 퍼플
    styleTag: '실전 심화 전문가',
    emoji: '🎯',
    animatedPoses: true,
  ),
];

TutorProfile tutorProfileById(String id) => tutorProfiles.firstWhere(
  (profile) => profile.id == id,
  orElse: () => tutorProfiles.first,
);

/// 사용자가 고른 강사 이미지를 원본 비율로 표시한다.
/// 볼트쌤은 무드별 38개 포즈, 소연·하린·지윤은 무드별 50개 3D 포즈를
/// 순환하는 살아있는 애니메이션으로 표시한다.
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

  /// build에서 갱신되는 현재 강사 id — 프레임 목록 계산에 사용.
  String _profileId = 'volt';

  List<int> get _frames {
    final map = _profileId == 'volt' ? voltMoodPoses : teacherMoodPoses;
    return map[widget.mood] ?? map[TutorMood.idle]!;
  }

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

  String _poseAssetFor(TutorProfile profile) {
    final isVolt = profile.id == 'volt';
    final maxPose = isVolt ? 38 : 50;
    final int pose;
    if (widget.poseOverride != null) {
      pose = widget.poseOverride!.clamp(1, maxPose);
    } else {
      final frames = _frames;
      pose = frames[_frameIdx % frames.length];
    }
    return isVolt ? voltPoseAsset(pose) : teacherPoseAsset(profile.id, pose);
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.characterId == 'selected'
        ? context.select<AppProvider, String>((app) => app.selectedTutorId)
        : widget.characterId;
    final profile = tutorProfileById(selectedId);
    _profileId = profile.id;
    final cs = Theme.of(context).colorScheme;

    // 모든 강사가 무드별 3D 포즈 프레임을 순환한다.
    final asset = profile.animatedPoses
        ? _poseAssetFor(profile)
        : profile.asset;
    final headOnly = widget.headOnly;
    // 이미지 실측 비율: 볼트 pose 프레임 132×292(0.452), 강사 포즈 280×560(0.50).
    // 비율 + 여유분을 더해 어떤 상황에서도 잘리지 않게 한다.
    final ratio = profile.id == 'volt' ? 0.46 : 0.50;
    final width = headOnly ? widget.size : widget.size * (ratio + 0.08);

    final Widget image = Image.asset(
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
          // asset을 key로 사용해 같은 이미지 2장이 겹쳐 보이는 중복을 방지.
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
