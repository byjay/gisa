import 'exam_track.dart';
import 'remote_content_api.dart';

class TrackCatalogService {
  TrackCatalogService._();

  static Future<void>? _loading;

  static Future<void> load() => _loading ??= RemoteContentApi.instance
      .getTrackCatalog()
      .then(setExamTrackCatalog);

  static void retry() {
    _loading = null;
  }
}
