import 'dart:io';

/// Saves CSV content to a sensible location (Downloads when available).
/// Returns the absolute path where the file was written, or null on failure.
Future<String?> saveCsvFile(String filename, String content) async {
  try {
    final String base;
    if (Platform.isWindows) {
      base = '${Platform.environment['USERPROFILE']}\\Downloads';
    } else {
      base = '${Platform.environment['HOME']}/Downloads';
    }
    final dir = Directory(base);
    final sep = Platform.isWindows ? '\\' : '/';
    final savePath = (await dir.exists()) ? '$base$sep$filename' : '${Directory.systemTemp.path}$sep$filename';
    await File(savePath).writeAsString(content);
    return savePath;
  } catch (e) {
    return null;
  }
}
