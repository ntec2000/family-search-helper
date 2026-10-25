import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_store.dart';

/// 파일 경로·브라우저 이미지 모두 원본 바이트로 표시한다.
class SourceImage extends StatefulWidget {
  final String path;
  final BoxFit fit;
  const SourceImage(this.path, {super.key, this.fit = BoxFit.contain});
  @override
  State<SourceImage> createState() => _SourceImageState();
}

class _SourceImageState extends State<SourceImage> {
  late Future<Uint8List> _bytes;
  @override
  void initState() {
    super.initState();
    _bytes = readImageBytes(widget.path);
  }
  @override
  void didUpdateWidget(SourceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _bytes = readImageBytes(widget.path);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Center(child: Text('원본 이미지를 읽을 수 없습니다.'));
      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
      return Image.memory(snapshot.data!, fit: widget.fit,
          semanticLabel: '인식 근거가 되는 족보 원본');
    },
  );
}
