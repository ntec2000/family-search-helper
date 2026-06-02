import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/hanja_dict.dart';
import 'services/db_service.dart';
import 'services/familysearch_service.dart';

Future<void> main() async {
  // 전역 오류 핸들러 — 예기치 못한 오류로 앱이 강제 종료되지 않도록 한다.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 프레임워크 오류를 콘솔에만 기록하고 앱은 유지
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    // 플랫폼/엔진 비동기 오류 흡수
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      debugPrint('PlatformDispatcher error: $error');
      return true;
    };

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // 자산 사전 / DB 로딩
    await HanjaDict.instance.load();
    await DbService.instance.open();
    await FamilySearchService.loadConfig();

    runApp(const ProviderScope(child: FamilySearchHelperApp()));
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}
