import 'dart:io';
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

class CaptureScreen extends StatefulWidget {
  final String? imagePath;

  /// v2.7 — [족보작성] 흐름에서 미리 입력받은 성씨(姓).
  /// 인식 결과의 가문(본관) 성씨로 강제 적용되어, 자녀 이름을 "성+이름"으로
  /// 표기하고 딸은 "○씨"로 표기한다. (자동 감지보다 우선)
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

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _camera;
  bool _busy = false;
  String _status = '';

  /// 미리보기로 표시 중인 (촬영·선택한) 이미지 경로.
  /// 이 값이 설정되면 이미지를 화면에 보여주기만 하고, OCR 은
  /// 사용자가 "한자 인식 시작" 을 누를 때만 실행한다. (자동 실행 X)
  String? _previewPath;

  bool get _hasPresetSurname =>
      (widget.surnameHangul ?? '').isNotEmpty ||
      (widget.surnameHanja ?? '').isNotEmpty;

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
        if (mounted) setState(() => _status = '카메라 권한이 필요합니다. 갤러리에서 선택할 수 있습니다.');
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _status = '사용 가능한 카메라가 없습니다. 갤러리에서 선택할 수 있습니다.');
        return;
      }
      final c =
          CameraController(cams.first, ResolutionPreset.veryHigh, enableAudio: false);
      await c.initialize();
      if (!mounted) return;
      setState(() => _camera = c);
    } catch (e) {
      if (mounted) setState(() => _status = '카메라 초기화 오류: $e\n갤러리에서 선택할 수 있습니다.');
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

  /// v2.7 — 같은 화면에서 갤러리 이미지 선택(올리기). 선택하면 미리보기로 표시.
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

  /// #1 — 필요한 부분만 잘라서 추출. 현재 미리보기 이미지를 자르기 화면으로
  /// 보내고, 돌아온 잘린 이미지 경로로 미리보기를 교체한다.
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

  /// ML Kit 네이티브 디코더가 일부 JPEG(프로그레시브·색프로파일·EXIF)에서
  /// 강제 종료되는 것을 방지하기 위해, Dart 측에서 표준 베이스라인 JPEG로
  /// 다시 인코딩한 임시 파일을 만들어 그 경로를 사용한다.
  ///
  /// v2.7 — 한자 인식 정확도 향상(#4):
  ///   · 글자가 작은 족보는 고해상도로 업스케일(최대 폭 2400) 하여 획을 또렷하게
  ///   · 흐린 목판·먹 인쇄 대응을 위해 채도를 낮추고(회색조 효과) 대비를 높임
  ///   · 위 전처리 후 표준 베이스라인 JPEG(고품질)로 재인코딩
  Future<String> _normalizeImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('지원하지 않는 이미지 형식이거나 파일이 손상되었습니다');
    }
    img.Image work = img.bakeOrientation(decoded);

    // 해상도 정규화 — 너무 작으면 업스케일(획 또렷), 너무 크면 다운스케일(메모리).
    final w = work.width;
    if (w > 0 && w < 2200) {
      work = img.copyResize(work,
          width: 2200, interpolation: img.Interpolation.cubic);
    } else if (w > 2600) {
      work = img.copyResize(work, width: 2600);
    }

    // 대비 향상 + 채도 제거(회색조화) — 인쇄 농담이 옅은 족보의 한자 인식률 개선.
    try {
      work = img.adjustColor(work, contrast: 1.18, saturation: 0.0);
    } catch (_) {
      // 전처리 실패 시에도 원본 정규화 이미지로 진행 (안전 폴백)
    }

    final jpg = img.encodeJpg(work, quality: 92);
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
      // 1) 안전한 표준 JPEG 로 정규화 + 인식 전처리 (네이티브 크래시 방지·정확도↑)
      final safePath = await _normalizeImage(path);

      if (!mounted) return;
      setState(() => _status = '한자 인식 중...');
      // 2) OCR
      final ocr = await OcrService.recognize(safePath);

      if (!mounted) return;
      setState(() => _status = '족보 정보 분석 중...');
      // 3) 파싱 — 미리 입력받은 성씨가 있으면 가문(본관) 성씨로 강제 적용
      final persons = JokboParser.parse(
        ocr.text,
        sourceImagePath: safePath,
        clanHanjaOverride: widget.surnameHanja,
        clanHangulOverride: widget.surnameHangul,
      );

      // 3-1) 성씨가 미리 입력되지 않았고, 인식 결과에 성씨 누락이 있으면
      //      수동 입력 → 전체 인물에 동일 적용 (v2.2)
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

      // 3-2) 저장
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

  /// #6 — 직접 입력. 빈 인물 1명을 새로 만들어 DB 에 저장한 뒤
  /// 바로 인물카드(편집) 화면을 연다. (이전엔 빈 ResultScreen 이라 편집 불가)
  Future<void> _manualEntry() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final person = Person(
        id: 'manual_${now.millisecondsSinceEpoch}',
        sourceImagePath: _previewPath,
        surnameHanja: widget.surnameHanja?.isEmpty ?? true
            ? null
            : widget.surnameHanja,
        surnameHangul: widget.surnameHangul?.isEmpty ?? true
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

  /// #5 — 다시 선택. 카메라 촬영이었으면 카메라를 다시 켜고,
  /// 갤러리에서 가져온 경우엔 이전(홈) 화면으로 돌아가 다시 고르게 한다.
  /// (이전엔 갤러리 경우 빈 화면에서 무한 로딩되던 버그)
  void _retake() {
    if (widget.imagePath != null) {
      // 홈에서 직접 갤러리 이미지를 들고 진입한 경우: 홈으로 돌아가 다시 선택
      Navigator.pop(context);
      return;
    }
    setState(() {
      _previewPath = null;
      _status = '';
    });
    if (_camera == null) _initCamera();
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
        actions: [
          if (!hasPreview)
            IconButton(
              icon: const Icon(Icons.photo_library_outlined),
              tooltip: '갤러리에서 선택',
              onPressed: _busy ? null : _pickFromGallery,
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1) 미리보기(촬영/선택한 이미지) — 표시만, 자동 인식 안 함
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
          // 2) 카메라 라이브 프리뷰
          else if (_camera != null && _camera!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_camera!))
          // 3) 카메라 미사용/오류 — 안내 + 갤러리 선택 버튼
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_status.isNotEmpty) ...[
                      const Icon(Icons.image_outlined,
                          size: 64, color: HanjiColors.mukSoft),
                      const SizedBox(height: 12),
                      Text(_status, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('갤러리에서 선택'),
                      ),
                    ] else
                      const CircularProgressIndicator(),
                  ],
                ),
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
