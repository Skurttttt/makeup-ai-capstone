import 'dart:io';
import 'package:file_selector/file_selector.dart';

/// Saves CSV content via a native "Save As" dialog on desktop.
/// Returns the absolute path where the file was written, or null if the user
/// cancelled or the write failed.
Future<String?> saveCsvFile(String filename, String content) async {
  try {
    final path = await getSavePath(
      suggestedName: filename,
      acceptedTypeGroups: [
        const XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (path == null) return null; // user cancelled
    await File(path).writeAsString(content);
    return path;
  } catch (e) {
    return null;
  }
}
