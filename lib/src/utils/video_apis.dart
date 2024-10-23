import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/vimeo_models.dart';
import 'logger.dart';

String podErrorString(String val) {
  return '*\n------error------\n\n$val\n\n------end------\n*';
}

class VideoApis {
  static Future<Response> _makeRequestHash(String videoId, String? hash) {
    if (hash == null) {
      return http.get(
        Uri.parse('https://player.vimeo.com/video/$videoId/config'),
      );
    } else {
      return http.get(
        Uri.parse('https://player.vimeo.com/video/$videoId/config?h=$hash'),
      );
    }
  }

  static Future<List<VideoQalityUrls>?> getVimeoVideoQualityUrls(
    String videoId,
    String? hash,
  ) async {
    try {
      final response = await _makeRequestHash(videoId, hash);
      final jsonData = jsonDecode(response.body)['request']['files'];
      final dashData = jsonData['dash'];
      final hlsData = jsonData['hls'];
      final defaultCDN = hlsData['default_cdn'];
      final cdnVideoUrl = (hlsData['cdns'][defaultCDN]['url'] as String?) ?? '';
      final List<dynamic> rawStreamUrls =
          (dashData['streams'] as List<dynamic>?) ?? <dynamic>[];

      final List<VideoQalityUrls> vimeoQualityUrls = [];

      for (final item in rawStreamUrls) {
        final sepList = cdnVideoUrl.split('/sep/video/');
        final firstUrlPiece = sepList.firstOrNull ?? '';
        final lastUrlPiece =
            ((sepList.lastOrNull ?? '').split('/').lastOrNull) ??
                (sepList.lastOrNull ?? '');
        final String urlId =
            ((item['id'] ?? '') as String).split('-').firstOrNull ?? '';
        vimeoQualityUrls.add(
          VideoQalityUrls(
            quality: int.parse(
              (item['quality'] as String?)?.split('p').first ?? '0',
            ),
            url: '$firstUrlPiece/sep/video/$urlId/$lastUrlPiece',
          ),
        );
      }
      if (vimeoQualityUrls.isEmpty) {
        vimeoQualityUrls.add(
          VideoQalityUrls(
            quality: 720,
            url: cdnVideoUrl,
          ),
        );
      }

      return vimeoQualityUrls;
    } catch (error) {
      if (error.toString().contains('XMLHttpRequest')) {
        log(
          podErrorString(
            '(INFO) To play vimeo video in WEB, Please enable CORS in your browser',
          ),
        );
      }
      podLog('===== VIMEO API ERROR: $error ==========');
      rethrow;
    }
  }

  static Future<List<VideoQalityUrls>?> getVimeoPrivateVideoQualityUrls(
    String videoId,
    Map<String, String> httpHeader,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.vimeo.com/videos/$videoId'),
        headers: httpHeader,
      );
      final jsonData =
          (jsonDecode(response.body)['files'] as List<dynamic>?) ?? [];

      final List<VideoQalityUrls> list = [];
      for (int i = 0; i < jsonData.length; i++) {
        final String quality =
            (jsonData[i]['rendition'] as String?)?.split('p').first ?? '0';
        final int? number = int.tryParse(quality);
        if (number != null && number != 0) {
          list.add(
            VideoQalityUrls(
              quality: number,
              url: jsonData[i]['link'] as String,
            ),
          );
        }
      }
      return list;
    } catch (error) {
      if (error.toString().contains('XMLHttpRequest')) {
        log(
          podErrorString(
            '(INFO) To play vimeo video in WEB, Please enable CORS in your browser',
          ),
        );
      }
      podLog('===== VIMEO API ERROR: $error ==========');
      rethrow;
    }
  }

  static Future<List<VideoQalityUrls>?> getYoutubeVideoQualityUrls(
    String youtubeIdOrUrl,
    bool live,
  ) async {
    try {
      podLog('Fetching YouTube video quality URLs for: $youtubeIdOrUrl');
      final yt = YoutubeExplode();
      final urls = <VideoQalityUrls>[];

      final videoId = VideoId.parseVideoId(youtubeIdOrUrl);
      podLog('Parsed video ID: $videoId');

      if (live) {
        podLog('Fetching live stream URL');
        final url = await yt.videos.streamsClient
            .getHttpLiveStreamUrl(VideoId(youtubeIdOrUrl));
        urls.add(VideoQalityUrls(quality: 360, url: url));
      } else {
        podLog('Fetching video details');
        final video = await yt.videos.get(youtubeIdOrUrl);
        // TODO: YOUTUBE HAS STOPPED STREAMING ALL STREAMING URLS NOW GIVE 403 FORBIDDEN
        // Assume the video is available in 1080p and add lower quality options
        urls
          ..add(VideoQalityUrls(quality: 1080, url: video.url))
          ..add(VideoQalityUrls(quality: 720, url: video.url))
          ..add(VideoQalityUrls(quality: 480, url: video.url))
          ..add(VideoQalityUrls(quality: 360, url: video.url));
      }

      yt.close();
      podLog('Fetched YouTube video quality URLs: $urls');
      return urls;
    } catch (error) {
      podLog('Error fetching YouTube video quality URLs: $error');
      if (error.toString().contains('XMLHttpRequest')) {
        log(
          podErrorString(
            '(INFO) To play YouTube video in WEB, Please enable CORS in your browser',
          ),
        );
      }
      podLog('===== YOUTUBE API ERROR: $error ==========');
      return null;
    }
  }

  static Future<List<VideoQalityUrls>> getVideoQualityUrlsFromYoutube(
    String videoId,
    bool live,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://www.youtube.com/get_video_info?video_id=$videoId',
        ),
      );
      if (response.statusCode == 200) {
        final data = Uri.decodeFull(response.body);
        final playerResponse = jsonDecode(
          Uri.decodeFull(
            RegExp('player_response=(.*)&').firstMatch(data)!.group(1)!,
          ),
        );
        final streamingData = playerResponse['streamingData'];
        final formats = streamingData['formats'] as List<dynamic>;
        return formats
            .map(
              (format) => VideoQalityUrls(
                quality: int.tryParse(
                      format['qualityLabel']
                          .toString()
                          .replaceAll(RegExp(r'[^\d]'), ''),
                    ) ??
                    0,
                url: format['url'] as String? ?? '',
              ),
            )
            .toList();
      } else {
        throw Exception('Failed to load video info');
      }
    } catch (e) {
      podLog('Error fetching YouTube video URLs: $e');
      return [];
    }
  }
}
