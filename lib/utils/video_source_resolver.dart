import 'video_source_resolver_stub.dart'
    if (dart.library.html) 'video_source_resolver_web.dart' as impl;

Future<Uri> resolveVideoSourceForPlayback(
  Uri sourceUri,
  Map<String, String> headers,
) {
  return impl.resolveVideoSourceForPlayback(sourceUri, headers);
}

void releaseResolvedVideoSource(Uri resolvedUri) {
  impl.releaseResolvedVideoSource(resolvedUri);
}
