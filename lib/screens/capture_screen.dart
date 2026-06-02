import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

  @override
  void initState() {
    super.initState();
    if (widget.imagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _process(widget.imagePath!));
    } else {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    final perm = await Permission.camera.request();
    if (!perm.isGranted) {
      setState(() => _status = '카메라 권한이 필요합니다');
      return;
    }
    final cams = await availableCameras();
    if (cams.isEmpty) {
      setState(() => _status = '사용 가능한 카메라가 없습니다');
      return;
    }
    final c = CameraController(cams.first, ResolutionPreset.high, enableAudio: false);
    await c.initialize();
    if (!mounted) return;
    setState(() => _camera = c);
  }

  Future<void> _shoot() async {
    if (_camera == null) return;
    setState(() => _busy = true);
    try {
      final f = await _camera!.takePicture();
      await _process(f.path);
    } catch (e) {
      setState(() => _status = '촬영 오류: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _process(String path) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _status = '한자 인식 중...';
    });
    try {
      final ocr = await OcrService.recognize(path);
      if (!mounted) return;
      setState(() => _status = '족보 정보 분석 중...');
      final persons = JokboParser.parse(ocr.text, sourceImagePath: path);
      for (final p in persons) {
        await DbService.instance.upsertPerson(p);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ResultScreen(
                  rawText: ocr.text, persons: persons, imagePath: path)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
      });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('인식 오류'),
          content: Text('이미지를 처리하는 중 문제가 발생했습니다.\n'
              '사진이 너무 크거나 형식이 지원되지 않을 수 있습니다.\n\n'
              '다른 사진으로 다시 시도해 주세요.\n\n[$e]'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                if (Navigator.canPop(context)) Navigator.pop(context); // back to home
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('족보 촬영')),
      body: Stack(
        children: [
          if (_camera != null && _camera!.value.isInitialized)
            Positioned.fill(child: CameraPreview(_camera!))
          else if (widget.imagePath != null)
            Positioned.fill(
                child: Image.file(File(widget.imagePath!),
                    fit: BoxFit.contain, cacheWidth: 1200))
          else
            const Center(child: CircularProgressIndicator()),
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
                        style: const TextStyle(color: HanjiColors.hanji, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _camera == null
          ? null
          : FloatingActionButton.large(
              onPressed: _busy ? null : _shoot,
              child: const Icon(Icons.camera_alt, size: 32),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
