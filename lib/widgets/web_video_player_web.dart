// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui;

void registerVideoView(String viewId, String videoUrl) {
  final video = html.VideoElement()
    ..src = videoUrl
    ..controls = true
    ..autoplay = true
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.objectFit = 'contain'
    ..style.background = '#000'
    ..setAttribute('playsinline', 'true')
    ..setAttribute('preload', 'auto');

  ui.platformViewRegistry.registerViewFactory(viewId, (_) => video);
}
