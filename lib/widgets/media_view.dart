import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';

import '../services/repository.dart';
import '../theme.dart';
import 'ui.dart';

/// Media types match the server: video, audio, pdf, image, text, document.
String mediaKindForName(String name) {
  final extension = name.contains('.')
      ? name.split('.').last.toLowerCase()
      : '';
  return switch (extension) {
    'mp4' || 'webm' || 'ogg' || 'ogv' || 'mov' || 'm4v' => 'video',
    'mp3' || 'wav' || 'm4a' || 'aac' || 'flac' => 'audio',
    'pdf' => 'pdf',
    'png' || 'jpg' || 'jpeg' || 'webp' => 'image',
    'txt' => 'text',
    _ => 'document',
  };
}

IconData mediaIcon(String kind) => switch (kind) {
  'video' => Icons.play_circle_outline,
  'audio' => Icons.headphones_outlined,
  'pdf' => Icons.picture_as_pdf_outlined,
  'image' => Icons.image_outlined,
  'text' => Icons.article_outlined,
  _ => Icons.insert_drive_file_outlined,
};

/// Shows learning content inside the app only. It plays from the server with
/// the learner's sign-in, or from a copy saved through an approved download;
/// it never hands the file to another app.
class MediaView extends StatelessWidget {
  final Repository repo;
  final String kind;
  final String title;
  final String? url;
  final File? file;
  const MediaView({
    super.key,
    required this.repo,
    required this.kind,
    required this.title,
    this.url,
    this.file,
  }) : assert(url != null || file != null);

  @override
  Widget build(BuildContext context) => switch (kind) {
    'video' || 'audio' => PlayerView(
      key: ValueKey('${file?.path ?? url}'),
      repo: repo,
      url: url,
      file: file,
      audioOnly: kind == 'audio',
      title: title,
    ),
    'pdf' => _OpenButton(
      icon: Icons.picture_as_pdf_outlined,
      label: 'Read PDF',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfScreen(repo: repo, title: title, url: url, file: file),
        ),
      ),
    ),
    'image' => _BytesView(
      repo: repo,
      url: url,
      file: file,
      builder: (bytes) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, fit: BoxFit.contain, semanticLabel: title),
      ),
    ),
    'text' => _BytesView(
      repo: repo,
      url: url,
      file: file,
      builder: (bytes) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Brand.paper,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          utf8.decode(bytes, allowMalformed: true),
          style: const TextStyle(height: 1.5),
        ),
      ),
    ),
    _ => const NoticeCard(
      icon: Icons.insert_drive_file_outlined,
      text:
          'This file type cannot be shown in the app. Ask your instructor for a PDF, video, audio or image version.',
    ),
  };
}

class _OpenButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OpenButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
  );
}

class _BytesView extends StatefulWidget {
  final Repository repo;
  final String? url;
  final File? file;
  final Widget Function(Uint8List bytes) builder;
  const _BytesView({
    required this.repo,
    required this.url,
    required this.file,
    required this.builder,
  });

  @override
  State<_BytesView> createState() => _BytesViewState();
}

class _BytesViewState extends State<_BytesView> {
  late Future<Uint8List> bytes = load();

  Future<Uint8List> load() => widget.file != null
      ? widget.file!.readAsBytes()
      : widget.repo.fetchBytes(widget.url!);

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return NoticeCard(
          icon: Icons.cloud_off,
          warning: true,
          text: snapshot.error.toString(),
          action: TextButton(
            onPressed: () => setState(() => bytes = load()),
            child: const Text('Retry'),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return widget.builder(snapshot.data!);
    },
  );
}

/// Full-screen PDF reader. Streamed PDFs are held in memory only.
class PdfScreen extends StatefulWidget {
  final Repository repo;
  final String title;
  final String? url;
  final File? file;
  const PdfScreen({
    super.key,
    required this.repo,
    required this.title,
    this.url,
    this.file,
  });

  @override
  State<PdfScreen> createState() => _PdfScreenState();
}

class _PdfScreenState extends State<PdfScreen> {
  late Future<Uint8List?> bytes = load();

  Future<Uint8List?> load() async =>
      widget.file != null ? null : widget.repo.fetchBytes(widget.url!);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: widget.file != null
        ? PdfViewer.file(widget.file!.path)
        : FutureBuilder<Uint8List?>(
            future: bytes,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return PageList(
                  children: [
                    EmptyState(
                      icon: Icons.cloud_off,
                      title: 'Could not open this PDF',
                      message: snapshot.error.toString(),
                      action: FilledButton(
                        onPressed: () => setState(() => bytes = load()),
                        child: const Text('Try again'),
                      ),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return PdfViewer.data(snapshot.data!, sourceName: widget.title);
            },
          ),
  );
}

/// Video and audio player with simple controls and full-screen viewing.
class PlayerView extends StatefulWidget {
  final Repository repo;
  final String? url;
  final File? file;
  final bool audioOnly;
  final String title;
  const PlayerView({
    super.key,
    required this.repo,
    this.url,
    this.file,
    this.audioOnly = false,
    required this.title,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  VideoPlayerController? controller;
  Object? error;
  bool started = false;

  /// The player starts only when the learner presses play, so opening a lesson uses no data.
  Future<void> start() async {
    setState(() {
      started = true;
      error = null;
    });
    final created = widget.file != null
        ? VideoPlayerController.file(widget.file!)
        : VideoPlayerController.networkUrl(
            Uri.parse(widget.url!),
            httpHeaders: widget.repo.authHeaders,
          );
    try {
      await created.initialize();
      if (!mounted) {
        await created.dispose();
        return;
      }
      created.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() => controller = created);
      await created.play();
    } catch (e) {
      await created.dispose();
      if (mounted) {
        setState(() {
          error = widget.file == null
              ? 'Could not play this ${widget.audioOnly ? 'audio' : 'video'}. Check your internet connection and try again.'
              : 'Could not play the saved file.';
          started = false;
        });
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = controller;
    if (error != null) {
      return NoticeCard(
        icon: Icons.error_outline,
        warning: true,
        text: '$error',
        action: TextButton(onPressed: start, child: const Text('Retry')),
      );
    }
    if (player == null) {
      return AspectRatio(
        aspectRatio: widget.audioOnly ? 4 : 16 / 9,
        child: Material(
          color: widget.audioOnly ? Brand.greenSoft : Brand.greenDark,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: started ? null : start,
            child: Center(
              child: started
                  ? CircularProgressIndicator(
                      color: widget.audioOnly ? Brand.green : Colors.white,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.audioOnly
                              ? Icons.headphones
                              : Icons.play_circle_fill,
                          size: widget.audioOnly ? 30 : 54,
                          color: widget.audioOnly ? Brand.green : Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.audioOnly ? 'Play audio' : 'Play video',
                          style: TextStyle(
                            color: widget.audioOnly
                                ? Brand.green
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.audioOnly)
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: player.value.aspectRatio == 0
                  ? 16 / 9
                  : player.value.aspectRatio,
              child: GestureDetector(
                onTap: () =>
                    player.value.isPlaying ? player.pause() : player.play(),
                child: VideoPlayer(player),
              ),
            ),
          ),
        PlayerControls(
          controller: player,
          onFullScreen: widget.audioOnly
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenPlayer(
                      controller: player,
                      title: widget.title,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class PlayerControls extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback? onFullScreen;
  final bool light;
  const PlayerControls({
    super.key,
    required this.controller,
    this.onFullScreen,
    this.light = false,
  });

  String clock(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return value.inHours > 0
        ? '${value.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final color = light ? Colors.white : Brand.ink;
          final duration = value.duration.inMilliseconds;
          final position = value.position.inMilliseconds.clamp(
            0,
            duration == 0 ? 1 : duration,
          );
          void seek(int seconds) =>
              controller.seekTo(value.position + Duration(seconds: seconds));
          return Row(
            children: [
              IconButton(
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                color: color,
                onPressed: () =>
                    value.isPlaying ? controller.pause() : controller.play(),
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 34,
                ),
              ),
              IconButton(
                tooltip: 'Back 10 seconds',
                color: color,
                onPressed: () => seek(-10),
                icon: const Icon(Icons.replay_10),
              ),
              Expanded(
                child: Slider(
                  value: position.toDouble(),
                  max: (duration == 0 ? 1 : duration).toDouble(),
                  onChanged: duration == 0
                      ? null
                      : (ms) => controller.seekTo(
                          Duration(milliseconds: ms.round()),
                        ),
                ),
              ),
              Text(
                '${clock(value.position)} / ${clock(value.duration)}',
                style: TextStyle(fontSize: 12, color: color),
              ),
              IconButton(
                tooltip: 'Forward 10 seconds',
                color: color,
                onPressed: () => seek(10),
                icon: const Icon(Icons.forward_10),
              ),
              if (onFullScreen != null)
                IconButton(
                  tooltip: 'Full screen',
                  color: color,
                  onPressed: onFullScreen,
                  icon: const Icon(Icons.fullscreen),
                ),
            ],
          );
        },
      );
}

class FullScreenPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  const FullScreenPlayer({
    super.key,
    required this.controller,
    required this.title,
  });

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: 'Exit full screen',
                color: Colors.white,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.fullscreen_exit),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 0,
              child: PlayerControls(controller: controller, light: true),
            ),
          ],
        ),
      ),
    );
  }
}
