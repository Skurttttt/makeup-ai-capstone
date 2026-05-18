import 'dart:io';

Future<void> saveCsvFile(String filename, String content) async {
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
}
