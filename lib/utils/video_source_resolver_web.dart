// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:http/http.dart' as http;

final Set<String> _blobUrls = <String>{};

Future<Uri> resolveVideoSourceForPlayback(
  Uri sourceUri,
  Map<String, String> headers,
) async {
  final response = await http.get(sourceUri, headers: headers);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode}');
  }

  final contentType =
      response.headers['content-type']?.trim().isNotEmpty == true
          ? response.headers['content-type']!
          : 'video/mp4';
  final blob = html.Blob(<Object>[response.bodyBytes], contentType);
  final blobUrl = html.Url.createObjectUrlFromBlob(blob);
  _blobUrls.add(blobUrl);
  return Uri.parse(blobUrl);
}

void releaseResolvedVideoSource(Uri resolvedUri) {
  if (resolvedUri.scheme != 'blob') return;
  final url = resolvedUri.toString();
  if (_blobUrls.remove(url)) {
    html.Url.revokeObjectUrl(url);
  }
}
