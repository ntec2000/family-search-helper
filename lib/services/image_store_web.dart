import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

Future<Uint8List> readImageBytes(String path) async {
  if (path.startsWith('data:')) return UriData.parse(path).contentAsBytes();
  final response = await http.get(Uri.parse(path));
  if (response.statusCode != 200) throw StateError('이미지를 읽을 수 없습니다.');
  return response.bodyBytes;
}

Future<String> storeImageBytes(Uint8List bytes,
    {bool temporary = true, String extension = 'jpg'}) async =>
    'data:${extension == 'pdf' ? 'application/pdf' : 'image/${extension == 'jpg' ? 'jpeg' : extension}'};base64,${base64Encode(bytes)}';

Future<String> persistSourceImage(String path) async =>
    storeImageBytes(await readImageBytes(path));
