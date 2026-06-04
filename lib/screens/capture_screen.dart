import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/person.dart';
import '../services/ocr_service.dart';
import '../services/jokbo_parser.dart';
import '../services/db_service.dart';
import '../theme/traditional_theme.dart';
import '../widgets/surname_input_dialog.dart';
import 'result_screen.dart';
import 'crop_screen.dart';
import 'person_card_screen.dart';

/// 백그라운드 아이솔레이트에서 실행되는 이미지 전처리.
/// 메인(UI) 스레드를 막지 않도록 compute() 로 분리한다. (ANR 방지)
/// 디코드 실패 시 빈 바이트를 반환하여 호출부에서 예외 처리한다.
Uint8List _processImageBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return Uint8List(0);
  img.Image work = img.bakeOrientation(decoded);
  final w = work.width;
  if (w > 0 && w < 2200) {
    work = img.copyResize(work, width: 2200, interpolation: img.Interpolation.cubic);
  } else if (w > 2600) {
    work = img.copyResize(work, width: 2600);
  }
  try {
    work = img.adjustColor(work, contrast: 1.18, saturation: 0.0);
  } catch (_) {}
  return Uint8List.fromList(img.encodeJpg(work, quality: 92));
}

class CaptureScreen extends StatefulWidget {
  final String? imagePath;

  /// v2.7 — [족보작성] 흐름에서 미리 입력받은 성씨(姓).
  final String? surnameHanja;
  final String? surnameHangul;

  const CaptureScreen({
    super.key,
    this.imagePath,
    this.surnameHanja,
    this.surnameHangul,
  });

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

enum _Mode { select, camera }

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _camera;
  bool _busy = false;
  String _status = '';

  /// v2.8 — 입력 소스 선택 모드. 진입 시에는 카메라를 자동으로 켜지 않고
  /// [카메라]/[갤러리] 선택 화면을 보여준다. (자동 카메라 구동으로 인한
  /// 화면 멈춤·ANR 방지 + 사용자가 명시적으로 선택)
  _Mode _mode = _Mode.select;

  /// 미리보기로 표시 중인 (촬영·선택한) 이미지 경로.
  String? _previewPath;

  bool get _hasPresetSurname =>
      (widget.surnameHangul ?? '').isNotEmpty ||
      (widget.surnameHanja ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    // 홈에서 이미지를 들고 진입한 경우(레거시)는 바로 미리보기.
    if (widget.imagePath != null) {
      _previewPath = widget.imagePath;
    }
    // 그 외에는 선택 화면(_Mode.select)으로 시작 — 카메라 자동 구동 안 함.
  }

  /// 사용자가 [카메라로 촬영] 을 선택했을 때만 카메라를 초기화한다.
  Future<void> _useCamera() async {
    setState(() {
      _mode = _Mode.camera;
      _status = '카메라 준비 중...';
    });
    try {
      final perm = await Permission.camera.request();
      if (!perm.isGranted) {
        if (mounted) {
          setState(() =>
              _status = '카메라 권한이 없습니다. [갤러리에서 선택] 을 이용해 주세요.');
        }
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) {
          setState(() =>
              _status = '사용 가능한 카메라가 없습니다. [갤러리에서 선택] 을 이용해 주세요.');
        }
        return;
      }
      final c = CameraController(cams.first, ResolutionPreset.veryHigh,
          enableAudio: false);
      await c.initialize();
      if (!mounted) return;
      setState(() {
        _camera = c;
        _status = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() => _status = '카메라 초기화 오류: $e\n[갤러리에서 선택] 을 이용해 주세요.');
      }
    }
  }

  Future<void> _shoot() async {
    if (_camera == null) return;
    setState(() => _busy = true);
    try {
      final f = await _camera!.takePicture();
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

  /// 갤러리 이미지 선택. 선택하면 미리보기로 표시.
  Future<void> _pickFromGallery() async {
    if (_busy) return;
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2600,
        maxHeight: 2600,
        imageQuality: 95,
      );
      if (x != null && mounted) {
        setState(() {
          _previewPath = x.path;
          _status = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = '이미지를 불러오지 못했습니다: $e');
      }
    }
  }

  Future<void> _cropImage() async {
    final path = _previewPath;
    if (path == null || _busy) return;
    final cropped = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => CropScreen(imagePath: path)),
    );
    if (cropped != null && cropped.isNotEmpty && mounted) {
      setState(() => _previewPath = cropped);
    }
  }

  /// ML Kit 네이티브 디코더 크래시 방지 + 인식 정확도 향상 전처리.
  /// v2.8 — 무거운 디코드/리사이즈/색보정은 백그라운드 아이솔레이트(compute)에서
  /// 수행하여 UI 스레드 멈춤(ANR)을 막는다.
  Future<String> _normalizeImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final jpg = await compute(_processImageBytes, bytes);
    if (jpg.isEmpty) {
      throw Exception('지원하지 않는 이미지 형식이거나 파일이 손상되었습니다');
    }
    final dir = await getTemporaryDirectory();
    final out = File(
        p.join(dir.path, 'ocr_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    await out.writeAsBytes(jpg, flush: true);
    return out.path;
  }

  /// 사용자가 명시적으로 "한자 인식 시작" 을 눌렀을 때만 호출.
  Future<void> _runOcr() async {
    final path = _previewPath;
    if (path == null || _busy) return;
    if (!mounted) return;
    setState(() {
      _busy = true;
      _status = '이미지 준비 중...';
    });
    try {
      final safePath = await _normalizeImage(path);

      if (!mounted) return;
      setState(() => _status = '한자 인식 중...');
      final ocr = await OcrService.recognize(safePath);

      if (!mounted) return;
      setState(() => _status = '족보 정보 분석 중...');
      final persons = JokboParser.parse(
        ocr.text,
        sourceImagePath: safePath,
        clanHanjaOverride: widget.surnameHanja,
        clanHangulOverride: widget.surnameHangul,
      );

      if (!_hasPresetSurname) {
        final needsSurname = persons.any((p) =>
            (p.surnameHanja ?? '').isEmpty && (p.surnameHangul ?? '').isEmpty);
        if (needsSurname && persons.isNotEmpty && mounted) {
          final entered = await showSurnameInputDialog(context);
          if (entered != null) {
            final sHanja = entered.$1, sHangul = entered.$2;
            for (final p in persons) {
              if ((p.surnameHanja ?? '').isEmpty &&
                  (p.surnameHangul ?? '').isEmpty) {
                p.surnameHanja = sHanja.isEmpty ? null : sHanja;
                p.surnameHangul = sHangul.isEmpty ? null : sHangul;
              }
            }
          }
        }
      }

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

  Future<void> _manualEntry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final person = Person(
        id: 'manual_${now.millisecondsSinceEpoch}',
        sourceImagePath: _previewPath,
        surnameHanja:
            (widget.surnameHanja?.isEmpty ?? true) ? null : widget.surnameHanja,
        surnameHangul: (widget.surnameHangul?.isEmpty ?? true)
            ? null
            : widget.surnameHangul,
        createdAt: now,
        updatedAt: now,
      );
      await DbService.instance.upsertPerson(person);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PersonCardScreen(personId: person.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = '직접 입력 준비 오류: $e';
        });
      }
    }
  }

  /// 다시 선택: 미리보기를 지우고 소스 선택 화면으로 되돌린다.
  void _retake() {
    if (widget.imagePath != null) {
      Navigator.pop(context);
      return;
    }
    _camera?.dispose();
    setState(() {
      _previewPath = null;
      _camera = null;
      _status = '';
      _mode = _Mode.select;
    });
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
      appBar: AppBar(
        title: Text(hasPreview ? '이미지 확인' : '족보 이미지 입력'),
      ),
      body: Stack(
        children: [
          if (hasPreview)
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 6.0,
                  panEnabled: true,
                  child: Image.file(File(_previewPath!),
                      fit: BoxFit.contain, cacheWidth: 1600),
                ),
              ),
            )
          else if (_mode == _Mode.camera &&
              _camera != null &&
              _camera!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_camera!))
          else if (_mode == _Mode.camera)
            // 카메라 준비 중 / 오류 — 안내 + 갤러리 폴백
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_status.isNotEmpty) ...[
                      const Icon(Icons.photo_camera_outlined,
                          size: 64, color: HanjiColors.mukSoft),
                      const SizedBox(height: 12),
                      Text(_status, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('갤러리에서 선택'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            setState(() => _mode = _Mode.select),
                        child: const Text('처음으로'),
                      ),
                    ] else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
            )
          else
            // v2.8 — 입력 소스 선택 화면 (카메라 / 갤러리)
            _SourceSelect(
              presetLine: _hasPresetSurname
                  ? '적용 성씨: '
                      '${(widget.surnameHanja ?? '').isNotEmpty ? '${widget.surnameHanja} ' : ''}'
                      '${widget.surnameHangul ?? ''}'
                  : null,
              onCamera: _useCamera,
              onGallery: _pickFromGallery,
            ),

          // 미리보기 상태의 하단 동작 버튼
          if (hasPreview && !_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                color: Colors.black.withValues(alpha: 0.55),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasPresetSurname)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '적용 성씨: ${(widget.surnameHanja ?? '').isNotEmpty ? '${widget.surnameHanja} ' : ''}${widget.surnameHangul ?? ''}',
                          style: const TextStyle(
                              color: HanjiColors.hanji, fontSize: 13),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _cropImage,
                            icon: const Icon(Icons.crop,
                                color: HanjiColors.hanji),
                            label: const Text('영역 선택 (자르기)',
                                style: TextStyle(color: HanjiColors.hanji)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
      floatingActionButton: (_mode == _Mode.camera &&
              !hasPreview &&
              _camera != null &&
              _camera!.value.isInitialized &&
              !_busy)
          ? FloatingActionButton.large(
              onPressed: _shoot,
              child: const Icon(Icons.camera_alt, size: 32),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// 입력 소스(카메라/갤러리) 선택 화면.
class _SourceSelect extends StatelessWidget {
  final String? presetLine;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  const _SourceSelect({
    required this.presetLine,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book, size: 72, color: HanjiColors.muk),
            const SizedBox(height: 12),
            const Text('족보 이미지 입력',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: HanjiColors.muk)),
            const SizedBox(height: 6),
            const Text('카메라로 촬영하거나 갤러리에서 이미지를 선택하세요',
                textAlign: TextAlign.center,
                style: TextStyle(color: HanjiColors.mukSoft)),
            if (presetLine != null) ...[
              const SizedBox(height: 10),
              Text(presetLine!,
                  style: const TextStyle(
                      color: HanjiColors.ju, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.photo_camera, size: 24),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('카메라로 촬영', style: TextStyle(fontSize: 17)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 24),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('갤러리에서 선택', style: TextStyle(fontSize: 17)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
