import 'package:flutter_test/flutter_test.dart';
import 'package:pod_player/pod_player.dart';
import 'package:pod_player/src/controllers/pod_getx_video_controller.dart';

void main() {
  group('YouTube Player Tests', () {
    late PodPlayerController podPlayerController;
    late PodGetXVideoController podGetXVideoController;

    setUp(() {
      podPlayerController = PodPlayerController(
        playVideoFrom: PlayVideoFrom.youtube(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
      );
      podGetXVideoController = PodGetXVideoController();
    });

    tearDown(() {
      podPlayerController.dispose();
    });

    test('Initialize YouTube video', () async {
      expect(podPlayerController.isInitialised, false);
      await podPlayerController.initialise();
      expect(podPlayerController.isInitialised, true);
    });

    test('Extract YouTube video ID', () {
      final videoId = podGetXVideoController
          .extractYoutubeVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      expect(videoId, 'dQw4w9WgXcQ');
    });

    test('Handle invalid YouTube URL', () {
      final videoId = podGetXVideoController
          .extractYoutubeVideoId('https://www.invalid-url.com');
      expect(videoId, null);
    });

    test('Extract YouTube video ID from various URL formats', () {
      final testCases = {
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ': 'dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ': 'dQw4w9WgXcQ',
        'https://www.youtube.com/embed/dQw4w9WgXcQ': 'dQw4w9WgXcQ',
        'https://youtube.com/shorts/dQw4w9WgXcQ': 'dQw4w9WgXcQ',
        'invalid_url': null,
      };

      testCases.forEach((url, expectedId) {
        final extractedId = podGetXVideoController.extractYoutubeVideoId(url);
        expect(extractedId, expectedId, reason: 'Failed for URL: $url');
      });
    });

    // Add more tests as needed
  });
}
