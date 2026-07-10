import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/study_data.dart';

/// 추천 강의: 유튜브 링크 (웹에서는 새탭, 앱에서는 링크 복사)
class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<VideoLink>? _all;
  String _filter = '전체';

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadVideos().then((v) {
      if (mounted) setState(() => _all = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final filters = ['전체', '공통', ...kSubjects];
    final list = all == null
        ? <VideoLink>[]
        : all
            .where((v) => _filter == '전체' || v.subject == _filter)
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('추천 강의 (무료 유튜브)')),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      for (final f in filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(f, style: const TextStyle(fontSize: 12)),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final v = list[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.play_circle_fill,
                              color: Colors.red, size: 34),
                          title: Text(v.title,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${v.channel}\n${v.desc}',
                                style: const TextStyle(
                                    fontSize: 12, height: 1.4)),
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            tooltip: '링크 복사',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () => _copy(v.url),
                          ),
                          onTap: () => _open(v.url),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // 열 수 없으면 클립보드 복사로 폴백
      await _copy(url);
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('링크가 복사되었습니다: $url',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
