// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void saveCsvFile(String filename, String content) {
  final bytes = html.Blob([content], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
