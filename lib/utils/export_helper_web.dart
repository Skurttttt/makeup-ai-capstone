// ignore: avoid_web_libraries_in_flutter
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Save CSV and trigger browser download. Returns null to indicate there's
/// no local filesystem path available on web.
Future<String?> saveCsvFile(String filename, String content) async {
  final bytes = html.Blob([content], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return null;
}
