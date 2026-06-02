import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ocr_service.dart';
import '../services/jokbo_parser.dart';
import '../services/db_service.dart';
import '../theme/traditional_theme.dart';
import 'result_screen.dart';

class CaptureScreen extends StatefulWidget {
  final String? imagePath;
  const CaptureScreen({super.key, this.imagePath});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _camera;
  bool _busy = false;
  String _status = '';

  /// 미리보기로 표시 중인 (촬영·선택한) 이미지 경로.
  /// 이 값이 설정되면 이미지를 화면에 보여주기만 하고, OCR 은
  /// 사용자가 "한자 인식 시작" 을 누를 때만 실행한다. (자동 실행 X)
  String? _previewPath;

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) {
      // 갤러리에서 가져온 이미지는 표시만 한다. (강제 종료 방지)
      _previewPath = widget.imagePath;
    } else {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final perm = await Permission.camera.request();
      if (!perm.isGranted) {
        if (mounted) setState(() => _status = '카메라 권한이 필요합니다');
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _status = '사용 가능한 카메라가 없습니다');
        return;
      }
      final c =
          CameraController(cams.first, ResolutionPreset.high, enableAudio: false);
      await c.initialize();
      if (!mounted) return;
      setState(() => _camera = c);
    } catch (e) {
      if (mounted) setState(() => _status = '카메라 초기화 오류: $e');
    }
  }

  Future<void> _shoot() async {
    if (_camera == null) return;
    setState(() => _busy = true);
    try {
      final f = await _camera!.takePicture();
      // 촬영 후에도 자동 OCR 하지 않고 미리보기 → 사용자 확인 후 인식.
      if (!mounted) return;
      setState(() {
        _previewPath = f.path;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '촬영 오류: $e';
        });
      }
    }
  }

  /// ML Kit 네이티브 디코더가 일부 JPEG(프로그레시브·색프로파일·EXIF)에서
  /// 강제 종료되는 것을 방지하기 위해, Dart 측에서 표준 베이스라인 JPEG로
  /// 다시 인코딩한 임시 파일을 만들어 그 경로를 사용한다.
  Future<String> _normalizeImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('지원하지 않는 이미지 형식이거나 파일이 손상되었습니다');
    }
    final oriented = img.bakeOrientation(decoded);
    final normalized = oriented.width > 1600
        ? img.copyResize(oriented, width: 1600)
        : oriented;
    final jpg = img.encodeJpg(normalized, quality: 88);
    final dir = await getTemporaryDirectory();
    final out = File(
        p.join(dir.path, 'ocr_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await out.writeAsBytes(jpg, flush: true);
    return out.path;
  }

  /// 사용자가 명시적으로 "한자 인식 시작" 을 눌렀을 때만 호출된다.
  Future<void> _runOcr() async {
    final path = _previewPath;
    if (path == null || _busy) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _status = '이미지 준비 중...';
    });
    try {
      // 1) 안전한 표준 JPEG 로 정규화 (네이티브 크래시 방지)
      final safePath = await _normalizeImage(path);

      if (!mounted) return;
      setState(() => _status = '한자 인식 중...');
      // 2) OCR
      final ocr = await OcrService.recognize(safePath);

      if (!mounted) return;
      setState(() => _status = '족보 정보 분석 중...');
      // 3) 파싱 + 저장
      final persons = JokboParser.parse(ocr.text, sourceImagePath: safePath);
      for (final person in persons) {
        await DbService.instance.upsertPerson(person);
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
              rawText: ocr.text, persons: persons, imagePath: safePath),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
      });
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('인식 오류'),
          content: Text('이미지를 처리하는 중 문제가 발생했습니다.\n'
              '다른 사진으로 다시 시도하거나, 직접 입력을 이용해 주세요.\n\n[$e]'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  /// OCR 없이 바로 직접 입력 화면으로 (인식 실패 대비 안전 경로).
  void _manualEntry() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
            rawText: '', persons: const [], imagePath: _previewPath ?? ''),
      ),
    );
  }

  void _retake() {
    setState(() {
      _previewPath = null;
      _status = '';
    });
    if (widget.imagePath == null) _initCamera();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasPreview = _previewPath != null;
    return Scaffold(
      appBar: AppBar(title: Text(hasPreview ? '이미지 확인' : '족보 촬영')),
      body: Stack(
        children: [
          // 1) 미리보기(촬영/선택한 이미지) — 표시만, 자동 인식 안 함
          if (hasPreview)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: Image.file(File(_previewPath!),
                    fit: BoxFit.contain, cacheWidth: 1200),
              ),
            )
          // 2) 카메라 라이브 프리뷰
          else if (_camera != null && _camera!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_camera!))
          // 3) 로딩/상태
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_status.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_status, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ),

          // 미리보기 상태의 하단 동작 버튼
          if (hasPreview && !_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                color: Colors.black.withOpacity(0.55),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _runOcr,
                        icon: const Icon(Icons.text_fields),
                        label: const Text('한자 인식 시작',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retake,
                            icon: const Icon(Icons.refresh,
                                color: HanjiColors.hanji),
                            label: const Text('다시 선택',
                                style: TextStyle(color: HanjiColors.hanji)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _manualEntry,
                            icon: const Icon(Icons.edit,
                                color: HanjiColors.hanji),
                            label: const Text('직접 입력',
                                style: TextStyle(color: HanjiColors.hanji)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // 처리 중 오버레이
          if (_busy)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: HanjiColors.hanji),
                    const SizedBox(height: 16),
                    Text(_status,
                        style: const TextStyle(
                            color: HanjiColors.hanji, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: (_camera == null || hasPreview)
          ? null
          : FloatingActionButton.large(
              onPressed: _busy ? null : _shoot,
              child: const Icon(Icons.camera_alt, size: 32),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
