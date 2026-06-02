import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../theme/traditional_theme.dart';

/// #1 족보 촬영/선택 이미지에서 필요한 부분만 잘라내는 화면.
/// 외부 의존성 없이 image 패키지로 직접 자른다.
/// 잘라낸 이미지의 임시 파일 경로를 Navigator.pop 으로 반환한다. (취소 시 null)
class CropScreen extends StatefulWidget {
  final String imagePath;
  const CropScreen({super.key, required this.imagePath});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  // 크롭 영역을 이미지 표시 영역에 대한 비율(0~1)로 저장
  double _l = 0.08, _t = 0.08, _r = 0.92, _b = 0.92;
  int? _imgW, _imgH;
  bool _busy = false;
  static const double _minFrac = 0.08;
  static const double _handle = 28;

  @override
  void initState() {
    super.initState();
    _loadDimensions();
  }

  Future<void> _loadDimensions() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _imgW = frame.image.width;
          _imgH = frame.image.height;
        });
      }
      frame.image.dispose();
    } catch (_) {
      if (mounted) Navigator.pop(context, null);
    }
  }

  /// 표시 영역(contain) 사각형 계산
  Rect _displayRect(Size viewport) {
    final aspect = _imgW! / _imgH!;
    double w, h;
    if (viewport.width / viewport.height > aspect) {
      h = viewport.height;
      w = h * aspect;
    } else {
      w = viewport.width;
      h = w / aspect;
    }
    final dx = (viewport.width - w) / 2;
    final dy = (viewport.height - h) / 2;
    return Rect.fromLTWH(dx, dy, w, h);
  }

  Future<void> _doCrop() async {
    if (_imgW == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('decode failed');
      final oriented = img.bakeOrientation(decoded);
      final iw = oriented.width, ih = oriented.height;
      int x = (_l * iw).round().clamp(0, iw - 1);
      int y = (_t * ih).round().clamp(0, ih - 1);
      int w = ((_r - _l) * iw).round().clamp(1, iw - x);
      int h = ((_b - _t) * ih).round().clamp(1, ih - y);
      final cropped = img.copyCrop(oriented, x: x, y: y, width: w, height: h);
      final jpg = img.encodeJpg(cropped, quality: 92);
      final dir = await getTemporaryDirectory();
      final out = File(p.join(
          dir.path, 'crop_${DateTime.now().millisecondsSinceEpoch}.jpg'));
      await out.writeAsBytes(jpg, flush: true);
      if (mounted) Navigator.pop(context, out.path);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지를 자르는 중 문제가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: HanjiColors.hanji,
        iconTheme: const IconThemeData(color: HanjiColors.hanji),
        title: const Text('필요한 부분 선택',
            style: TextStyle(color: HanjiColors.hanji)),
      ),
      body: _imgW == null
          ? const Center(
              child: CircularProgressIndicator(color: HanjiColors.hanji))
          : LayoutBuilder(builder: (context, constraints) {
              final viewport = Size(constraints.maxWidth, constraints.maxHeight);
              final disp = _displayRect(viewport);
              final cropRect = Rect.fromLTRB(
                disp.left + _l * disp.width,
                disp.top + _t * disp.height,
                disp.left + _r * disp.width,
                disp.top + _b * disp.height,
              );
              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: disp,
                    child: Image.file(File(widget.imagePath),
                        fit: BoxFit.fill),
                  ),
                  // 어두운 마스크 + 테두리
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MaskPainter(cropRect),
                      ),
                    ),
                  ),
                  // 내부 이동
                  Positioned.fromRect(
                    rect: cropRect,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanUpdate: (d) {
                        setState(() {
                          final dxF = d.delta.dx / disp.width;
                          final dyF = d.delta.dy / disp.height;
                          final wF = _r - _l, hF = _b - _t;
                          _l = (_l + dxF).clamp(0.0, 1.0 - wF);
                          _t = (_t + dyF).clamp(0.0, 1.0 - hF);
                          _r = _l + wF;
                          _b = _t + hF;
                        });
                      },
                    ),
                  ),
                  // 네 모서리 핸들
                  _corner(cropRect.topLeft, disp, isLeft: true, isTop: true),
                  _corner(cropRect.topRight, disp, isLeft: false, isTop: true),
                  _corner(cropRect.bottomLeft, disp, isLeft: true, isTop: false),
                  _corner(cropRect.bottomRight, disp,
                      isLeft: false, isTop: false),
                  if (_busy)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: HanjiColors.hanji)),
                    ),
                ],
              );
            }),
      bottomNavigationBar: _imgW == null
          ? null
          : Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _busy ? null : () => Navigator.pop(context, null),
                    icon: const Icon(Icons.fullscreen,
                        color: HanjiColors.hanji),
                    label: const Text('전체 사용',
                        style: TextStyle(color: HanjiColors.hanji)),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: HanjiColors.hanji)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _doCrop,
                    icon: const Icon(Icons.crop),
                    label: const Text('자르기'),
                    style: FilledButton.styleFrom(
                        backgroundColor: HanjiColors.ju,
                        foregroundColor: HanjiColors.hanji),
                  ),
                ),
              ]),
            ),
    );
  }

  Widget _corner(Offset pos, Rect disp,
      {required bool isLeft, required bool isTop}) {
    return Positioned(
      left: pos.dx - _handle / 2,
      top: pos.dy - _handle / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          setState(() {
            final dxF = d.delta.dx / disp.width;
            final dyF = d.delta.dy / disp.height;
            if (isLeft) {
              _l = (_l + dxF).clamp(0.0, _r - _minFrac);
            } else {
              _r = (_r + dxF).clamp(_l + _minFrac, 1.0);
            }
            if (isTop) {
              _t = (_t + dyF).clamp(0.0, _b - _minFrac);
            } else {
              _b = (_b + dyF).clamp(_t + _minFrac, 1.0);
            }
          });
        },
        child: Container(
          width: _handle,
          height: _handle,
          decoration: BoxDecoration(
            color: HanjiColors.ju,
            shape: BoxShape.circle,
            border: Border.all(color: HanjiColors.hanji, width: 2),
          ),
        ),
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  final Rect crop;
  _MaskPainter(this.crop);

  @override
  void paint(Canvas canvas, Size size) {
    final mask = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRect(crop);
    final diff = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(diff, mask);
    final border = Paint()
      ..color = HanjiColors.ju
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(crop, border);
    // 3분할 가이드선
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      final dx = crop.left + crop.width * i / 3;
      canvas.drawLine(Offset(dx, crop.top), Offset(dx, crop.bottom), grid);
      final dy = crop.top + crop.height * i / 3;
      canvas.drawLine(Offset(crop.left, dy), Offset(crop.right, dy), grid);
    }
  }

  @override
  bool shouldRepaint(_MaskPainter old) => old.crop != crop;
}
