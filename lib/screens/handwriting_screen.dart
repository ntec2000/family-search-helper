import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/ocr_service.dart';
import '../services/hanja_dict.dart';
import '../theme/traditional_theme.dart';

/// #14 / #17 필기 한자 인식 도구 (네이버 한자 입력 방식 참조).
/// 손으로 한자를 그리면 내장 온디바이스 OCR(한자 모델)로 인식한다.
/// returnOnPick=true 이면 후보 한자 선택 시 그 글자를 Navigator.pop 으로 반환.
class HandwritingScreen extends StatefulWidget {
  final bool returnOnPick;
  const HandwritingScreen({super.key, this.returnOnPick = false});

  @override
  State<HandwritingScreen> createState() => _HandwritingScreenState();
}

class _HandwritingScreenState extends State<HandwritingScreen> {
  final _boundaryKey = GlobalKey();
  final List<List<Offset>> _strokes = [];
  List<Offset> _current = [];
  bool _busy = false;
  List<String> _candidates = [];
  String _status = '';

  void _start(Offset o) {
    setState(() {
      _current = [o];
      _strokes.add(_current);
    });
  }

  void _append(Offset o) {
    setState(() => _current.add(o));
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _current = [];
      _candidates = [];
      _status = '';
    });
  }

  void _undo() {
    setState(() {
      if (_strokes.isNotEmpty) _strokes.removeLast();
      _candidates = [];
    });
  }

  Future<void> _recognize() async {
    if (_strokes.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _status = '확인 중...';
      _candidates = [];
    });
    try {
      // 1) 그린 캔버스를 흰 배경 PNG 로 렌더링 (테두리 제외 → 인식 정확도 향상)
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 5.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) throw Exception('렌더 실패');
      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final f = File(p.join(
          dir.path, 'hw_${DateTime.now().millisecondsSinceEpoch}.png'));
      await f.writeAsBytes(bytes, flush: true);

      // 2) 내장 한자 OCR 로 인식
      final result = await OcrService.recognize(f.path);
      // 인식 텍스트에서 한자만 추출 (중복 제거)
      final chars = <String>[];
      for (final r in result.text.runes) {
        final ch = String.fromCharCode(r);
        if (RegExp(r'[一-鿿㐀-䶿]').hasMatch(ch)) {
          if (!chars.contains(ch)) chars.add(ch);
        }
      }
      setState(() {
        _busy = false;
        _candidates = chars;
        _status = chars.isEmpty
            ? '인식하지 못했습니다. 더 크고 또렷하게, 칸 가운데에 그려 주세요.'
            : '인식된 예상 한자 (눌러서 선택):';
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _status = '인식 오류: 다시 시도해 주세요.';
      });
    }
  }

  void _pick(String ch) {
    if (widget.returnOnPick) {
      Navigator.pop(context, ch);
    } else {
      final reading = HanjaDict.instance.reading(ch);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$ch ($reading) 복사 준비 — 길게 눌러 복사하세요')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('필기 한자 인식'),
        actions: [
          IconButton(
              onPressed: _undo,
              icon: const Icon(Icons.undo),
              tooltip: '한 획 지우기'),
          IconButton(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline),
              tooltip: '전체 지우기'),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Text(
                '아래 칸 가운데에 한자를 손으로 크게 그린 뒤 [결과 확인] 을 누르세요.\n'
                '(네이버 한자 필기 입력과 같은 방식 · 내장 OCR · 인터넷 불필요)',
                style: TextStyle(
                    color: HanjiColors.mukSoft, height: 1.4, fontSize: 12.5),
              ),
            ),
            // 그리기 캔버스 — 화면이 작아도 버튼이 보이도록 높이 제한
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: LayoutBuilder(builder: (context, _) {
                final side = MediaQuery.of(context).size;
                final box = side.width.clamp(0, 320).toDouble() - 32;
                final dim = box.clamp(180.0, 300.0);
                return Center(
                  child: Container(
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: HanjiColors.mukSoft, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      // RepaintBoundary 는 테두리를 포함하지 않는 순수 흰 캔버스
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: Container(
                          width: dim,
                          height: dim,
                          color: Colors.white,
                          child: GestureDetector(
                            onPanStart: (d) => _start(d.localPosition),
                            onPanUpdate: (d) => _append(d.localPosition),
                            child: CustomPaint(
                              painter: _StrokePainter(_strokes),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _recognize,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: HanjiColors.hanji))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_busy ? '확인 중...' : '결과 확인'),
                ),
              ),
            ),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_status,
                      style: const TextStyle(
                          color: HanjiColors.ju, fontWeight: FontWeight.w600)),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _candidates
                      .map((ch) => _CandidateCard(ch: ch, onTap: () => _pick(ch)))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// #15 인식된 예상 한자 + 한글 음(복수) + 뜻(훈음)
class _CandidateCard extends StatelessWidget {
  final String ch;
  final VoidCallback onTap;
  const _CandidateCard({required this.ch, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final d = HanjaDict.instance;
    final eum = d.readingsAll(ch);
    final hun = d.meanings(ch);
    return InkWell(
      onTap: onTap,
      onLongPress: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: HanjiColors.hanjiLight,
          border: Border.all(color: HanjiColors.muk, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ch,
                style: const TextStyle(fontSize: 36, color: HanjiColors.muk)),
            const SizedBox(height: 4),
            Text(eum.isEmpty ? '?' : '음: ${eum.join('·')}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    color: HanjiColors.cheong,
                    fontWeight: FontWeight.bold)),
            if (hun.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(hun.take(2).join(', '),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: HanjiColors.mukSoft, height: 1.3)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    // v2.6 — 더 가는 획 + 부드러운 곡선 보간(인식 정확도/가독성 향상)
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (final stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.isNotEmpty) {
          canvas.drawPoints(ui.PointMode.points, stroke, dotPaint);
        }
        continue;
      }
      // 점들의 중점을 지나는 2차 베지에로 부드럽게 연결한다.
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length - 1; i++) {
        final mid = Offset((stroke[i].dx + stroke[i + 1].dx) / 2,
            (stroke[i].dy + stroke[i + 1].dy) / 2);
        path.quadraticBezierTo(stroke[i].dx, stroke[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(stroke.last.dx, stroke.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter old) => true;
}
