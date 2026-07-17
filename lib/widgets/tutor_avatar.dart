import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';

enum TutorMood { idle, happy, thinking, wrong, teaching, meditate, cheer }

class TutorProfile {
  final String id;
  final String name;
  final String role;
  final String asset;

  const TutorProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.asset,
  });
}

const tutorProfiles = <TutorProfile>[
  TutorProfile(
    id: 'soyeon',
    name: '소연 선생님',
    role: '개념과 공식을 차분하게 연결하는 이론 강사',
    asset: 'assets/tutor/teacher_soyeon.png',
  ),
  TutorProfile(
    id: 'harin',
    name: '하린 선생님',
    role: '문제·정답을 빠르게 각인시키는 암기 코치',
    asset: 'assets/tutor/teacher_harin.png',
  ),
  TutorProfile(
    id: 'jiyoon',
    name: '지윤 선생님',
    role: '심화 이론과 실기 적용을 짚어주는 전문 강사',
    asset: 'assets/tutor/teacher_jiyoon.png',
  ),
];

TutorProfile tutorProfileById(String id) => tutorProfiles.firstWhere(
  (profile) => profile.id == id,
  orElse: () => tutorProfiles.first,
);

/// 사용자가 고른 전신 강사 이미지를 원본 비율로 표시한다.
/// 모든 화면에서 BoxFit.contain을 사용해 머리와 발이 잘리지 않는다.
class TutorAvatar extends StatelessWidget {
  final TutorMood mood;
  final double size;
  final Duration interval;
  final bool animate;
  final String characterId;
  final bool rotate;
  final bool headOnly;

  const TutorAvatar({
    super.key,
    this.mood = TutorMood.idle,
    this.size = 96,
    this.interval = const Duration(milliseconds: 2200),
    this.animate = true,
    this.headOnly = false,
    this.characterId = 'selected',
    this.rotate = true,
  });

  @override
  Widget build(BuildContext context) {
    final selectedId = context.select<AppProvider, String>(
      (app) => app.selectedTutorId,
    );
    final profile = tutorProfileById(selectedId);
    final cs = Theme.of(context).colorScheme;
    final width = headOnly ? size : size * 0.56;

    return Semantics(
      image: true,
      label: '${profile.name} 전신 캐릭터',
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        child: Container(
          key: ValueKey(profile.id),
          width: width,
          height: size,
          padding: EdgeInsets.all(headOnly ? size * 0.05 : 0),
          decoration: headOnly
              ? BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(size * 0.26),
                )
              : null,
          child: Image.asset(
            profile.asset,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => Icon(
              Icons.person_rounded,
              size: size * 0.65,
              color: cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 말풍선 포함 강사 배너 — 홈/슬라이드 화면용
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
                  Text(
                    tutor.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: cs.primary,
                    ),
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
                color: cs.primary.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }
}
