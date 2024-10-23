import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as uni_html;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../pod_player.dart';
import '../utils/logger.dart';
import '../utils/video_apis.dart';
import 'pod_getx_video_controller.dart';

class PodPlayerController {
  late PodGetXVideoController _ctr;
  late String getTag;
  bool _isCtrInitialised = false;

  Object? _initializationError;

  final PlayVideoFrom playVideoFrom;
  final PodPlayerConfig podPlayerConfig;

  /// controller for pod player
  PodPlayerController({
    required this.playVideoFrom,
    this.podPlayerConfig = const PodPlayerConfig(),
  }) {
    _init();
  }

  void _init() {
    getTag = UniqueKey().toString();
    Get.config(enableLog: PodVideoPlayer.enableGetxLogs);
    _ctr = Get.put(PodGetXVideoController(), permanent: true, tag: getTag)
      ..config(
        playVideoFrom: playVideoFrom,
        playerConfig: podPlayerConfig,
      );
  }

  /// Initializes the video player.
  ///
  /// If the provided video cannot be loaded, an exception could be thrown.
  Future<void> initialise() async {
    podLog('PodPlayerController: initialise started');
    try {
      // Integrate YouTube player's video fetching logic
      if (playVideoFrom.dataSource != null) {
        final videoId = _extractVideoId(playVideoFrom.dataSource!);
        if (videoId != null) {
          final videoUrls = await VideoApis.getYoutubeVideoQualityUrls(
            videoId,
            playVideoFrom.live,
          );
          if (videoUrls != null && videoUrls.isNotEmpty) {
            // Instead of modifying playVideoFrom, we'll use the fetched URL directly
            await _ctr.videoInit();
          } else {
            // If no URLs are found, proceed with the original dataSource
            await _ctr.videoInit();
          }
        } else {
          // If no video ID is extracted, proceed with the original dataSource
          await _ctr.videoInit();
        }
      } else {
        // If no dataSource is provided, proceed with the original videoInit
        await _ctr.videoInit();
      }
      podLog('PodPlayerController: videoInit completed');
      await _checkAndWaitTillInitialized();
      podLog('PodPlayerController: initialise completed');
    } catch (error) {
      podLog('PodPlayerController: Error during initialisation: $error');
      _initializationError = error;
      rethrow;
    }
  }

  Future<void> _checkAndWaitTillInitialized() async {
    podLog('PodPlayerController: _checkAndWaitTillInitialized started');
    if (!_ctr.initialized) {
      podLog('PodPlayerController: Video not initialized, waiting...');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _checkAndWaitTillInitialized();
    } else {
      podLog('PodPlayerController: Video initialized');
    }
  }

  /// returns the url of current playing video
  String? get videoUrl => _ctr.playingVideoUrl;

  /// returns true if video player is initialized
  bool get isInitialised => _ctr.videoCtr?.value.isInitialized ?? false;

  /// returns true if video is playing
  bool get isVideoPlaying => _ctr.videoCtr?.value.isPlaying ?? false;

  /// returns true if video is in buffering state
  bool get isVideoBuffering => _ctr.videoCtr?.value.isBuffering ?? false;

  /// returns true if `loop` is enabled
  bool get isVideoLooping => _ctr.videoCtr?.value.isLooping ?? false;

  /// returns true if video is in fullscreen mode
  bool get isFullScreen => _ctr.isFullScreen;

  bool get isMute => _ctr.isMute;

  PodVideoState get videoState => _ctr.podVideoState;

  VideoPlayerValue? get videoPlayerValue => _ctr.videoCtr?.value;

  PodVideoPlayerType get videoPlayerType => _ctr.videoPlayerType;

  // Future<void> initialize() async => _ctr.videoCtr?.initialize;

  //! video positions

  /// Returns the video total duration
  Duration get totalVideoLength => _ctr.videoDuration;

  /// Returns the current position of the video
  Duration get currentVideoPosition => _ctr.videoPosition;

  //! video play/pause

  /// plays the video
  void play() => _ctr.podVideoStateChanger(PodVideoState.playing);

  /// pauses the video
  void pause() => _ctr.podVideoStateChanger(PodVideoState.paused);

  /// toogle play and pause
  void togglePlayPause() {
    isVideoPlaying ? pause() : play();
  }

  /// Listen to changes in video.
  ///
  /// It only adds a listener if the player is successfully initialized
  void addListener(VoidCallback listener) {
    _checkAndWaitTillInitialized().then(
      (value) => _ctr.videoCtr?.addListener(listener),
    );
  }

  /// Remove registered listeners
  void removeListener(VoidCallback listener) {
    _checkAndWaitTillInitialized().then(
      (value) => _ctr.videoCtr?.removeListener(listener),
    );
  }

  //! volume Controllers

  /// mute the volume of the video
  Future<void> mute() async => _ctr.mute();

  /// unmute the volume of the video
  Future<void> unMute() async => _ctr.unMute();

  /// toggle the volume
  Future<void> toggleVolume() async {
    _ctr.isMute ? await _ctr.unMute() : await _ctr.mute();
  }

  ///Dispose pod video player controller
  void dispose() {
    _isCtrInitialised = false;
    _ctr.videoCtr?.removeListener(_ctr.videoListner);
    _ctr.videoCtr?.dispose();
    _ctr.removeListenerId('podVideoState', _ctr.podStateListner);
    if (podPlayerConfig.wakelockEnabled) WakelockPlus.disable();
    Get.delete<PodGetXVideoController>(
      force: true,
      tag: getTag,
    );
    podLog('$getTag Pod player Disposed');
  }

  /// used to change the video
  Future<void> changeVideo({
    required PlayVideoFrom playVideoFrom,
    PodPlayerConfig playerConfig = const PodPlayerConfig(),
  }) async {
    PlayVideoFrom updatedPlayVideoFrom = playVideoFrom;

    if (playVideoFrom.dataSource != null) {
      final videoId = _extractVideoId(playVideoFrom.dataSource!);
      if (videoId != null) {
        try {
          final videoUrls = await VideoApis.getYoutubeVideoQualityUrls(
            videoId,
            playVideoFrom.live,
          );
          if (videoUrls != null && videoUrls.isNotEmpty) {
            updatedPlayVideoFrom = PlayVideoFrom.network(videoUrls.first.url);
          }
        } catch (e) {
          podLog('Error fetching YouTube video URL: $e');
          // Fallback to original dataSource if fetching fails
        }
      }
    }

    return _ctr.changeVideo(
      playVideoFrom: updatedPlayVideoFrom,
      playerConfig: playerConfig,
    );
  }

  //Change double tap duration
  void setDoubeTapForwarDuration(int seconds) =>
      _ctr.doubleTapForwardSeconds = seconds;

  ///Jumps to specific position of the video
  Future<void> videoSeekTo(Duration moment) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.seekTo(moment);
  }

  ///Moves video forward from current duration to `_duration`
  Future<void> videoSeekForward(Duration duration) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.seekForward(duration);
  }

  ///Moves video backward from current duration to `_duration`
  Future<void> videoSeekBackward(Duration duration) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.seekBackward(duration);
  }

  ///on right double tap
  Future<void> doubleTapVideoForward(int seconds) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.onRightDoubleTap(seconds: seconds);
  }

  ///on left double tap
  Future<void> doubleTapVideoBackward(int seconds) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.onLeftDoubleTap(seconds: seconds);
  }

  /// Enables video player to fullscreen mode.
  ///
  /// If onToggleFullScreen is set, you must handle the device
  /// orientation by yourself.
  void enableFullScreen() {
    uni_html.document.documentElement?.requestFullscreen();
    _ctr.enableFullScreen(getTag);
  }

  /// Disables fullscreen mode.
  ///
  /// If onToggleFullScreen is set, you must handle the device
  /// orientation by yourself.
  void disableFullScreen(BuildContext context) {
    uni_html.document.exitFullscreen();

    if (!_ctr.isWebPopupOverlayOpen) {
      _ctr.disableFullScreen(context, getTag);
    }
  }

  /// listener for the changes in the quality of the video
  void onVideoQualityChanged(VoidCallback callback) {
    _ctr.onVimeoVideoQualityChanged = callback;
  }

  static Future<List<VideoQalityUrls>?> getYoutubeUrls(
    String youtubeIdOrUrl, {
    bool live = false,
  }) {
    return VideoApis.getYoutubeVideoQualityUrls(youtubeIdOrUrl, live);
  }

  static Future<List<VideoQalityUrls>?> getVimeoUrls(
    String videoId, {
    String? hash,
  }) {
    return VideoApis.getVimeoVideoQualityUrls(videoId, hash);
  }

  /// Hide overlay of video
  void hideOverlay() => _ctr.isShowOverlay(false);

  /// Show overlay of video
  void showOverlay() => _ctr.isShowOverlay(true);

  String? _extractVideoId(String url) {
    // Implement YouTube video ID extraction logic here
    // This is a simplified example, you may need to handle different URL formats
    final regex = RegExp(r'(?:youtube\.com\/watch\?v=|youtu.be\/)([^&\n?#]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }
}
