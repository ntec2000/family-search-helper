import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Uint8List> readImageBytes(String path) => File(path).readAsBytes();

Future<String> storeImageBytes(Uint8List bytes,
    {bool temporary = true, String extension = 'jpg'}) async {
  final dir = temporary
      ? await getTemporaryDirectory()
      : await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path,
      'source_${DateTime.now().microsecondsSinceEpoch}.$extension'));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> persistSourceImage(String path) async {
  final extension = p.extension(path).replaceFirst('.', '');
  return storeImageBytes(await readImageBytes(path), temporary: false,
      extension: extension.isEmpty ? 'jpg' : extension);
}
