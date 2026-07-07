// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

Future<Uint8List?> captureVideoThumbnail(String videoUrl) async {
  try {
    final video = html.VideoElement()
      ..src = videoUrl
      ..crossOrigin = 'anonymous'
      ..muted = true
      ..preload = 'metadata'
      ..style.display = 'none';

    html.document.body?.append(video);

    // Attend les métadonnées
    final metaCompleter = Completer<void>();
    late StreamSubscription metaSub;
    late StreamSubscription errSub;
    metaSub = video.onLoadedMetadata.listen((_) {
      if (!metaCompleter.isCompleted) metaCompleter.complete();
      metaSub.cancel();
    });
    errSub = video.onError.listen((_) {
      if (!metaCompleter.isCompleted) metaCompleter.completeError('err');
      errSub.cancel();
    });

    await metaCompleter.future.timeout(const Duration(seconds: 12));

    // Seek à ~10% de la durée
    final dur = video.duration.isNaN || video.duration.isInfinite ? 10.0 : video.duration;
    video.currentTime = (dur * 0.1).clamp(1.0, 5.0);

    final seekCompleter = Completer<void>();
    late StreamSubscription seekSub;
    seekSub = video.onSeeked.listen((_) {
      if (!seekCompleter.isCompleted) seekCompleter.complete();
      seekSub.cancel();
    });

    await seekCompleter.future.timeout(const Duration(seconds: 8));

    final w = video.videoWidth > 0 ? video.videoWidth : 640;
    final h = video.videoHeight > 0 ? video.videoHeight : 360;

    final canvas = html.CanvasElement(width: w, height: h);
    canvas.context2D.drawImage(video, 0, 0);
    video.remove();

    // data:image/jpeg;base64,XXXX
    final dataUrl = canvas.toDataUrl('image/jpeg', 0.75);
    final b64 = dataUrl.split(',').last;
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}
