import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maarif_learn/theme/app_colors.dart';

import 'video_thumbnail_web.dart' if (dart.library.io) 'video_thumbnail_stub.dart';

/// Widget qui affiche la vraie première frame d'une vidéo locale.
/// Sur web : capture via HTML5 Canvas. Sur mobile : placeholder stylé.
class VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final double width;
  final double height;

  const VideoThumbnailWidget({
    super.key,
    required this.videoUrl,
    this.width = double.infinity,
    this.height = 90,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  static final Map<String, Uint8List?> _cache = {};
  Uint8List? _frame;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_cache.containsKey(widget.videoUrl)) {
      if (mounted) setState(() { _frame = _cache[widget.videoUrl]; _loading = false; });
      return;
    }
    if (!kIsWeb) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final bytes = await captureVideoThumbnail(widget.videoUrl);
    _cache[widget.videoUrl] = bytes;
    if (mounted) setState(() { _frame = bytes; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: _shimmer(),
      );
    }

    if (_frame != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: Image.memory(
          _frame!,
          fit: BoxFit.cover,
          width: widget.width,
          height: widget.height,
        ),
      );
    }

    // Fallback placeholder si la capture a échoué
    return _Placeholder(width: widget.width, height: widget.height);
  }

  Widget _shimmer() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.7),
      duration: const Duration(milliseconds: 800),
      builder: (_, v, __) => Container(
        width: widget.width,
        height: widget.height,
        color: Color.lerp(const Color(0xFF0A2342), AppColors.teal, v * 0.3),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2342), Color(0xFF00B4C5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Motif décoratif
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          const Center(
            child: Icon(Icons.videocam_rounded, color: Colors.white30, size: 28),
          ),
        ],
      ),
    );
  }
}
