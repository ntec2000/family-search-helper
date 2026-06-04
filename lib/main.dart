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

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exceptionAsString()}');
    };
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      debugPrint('PlatformDispatcher error: $error');
      return true;
    };

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // v2.8 — 시작 단계의 어떤 초기화가 실패하더라도(자산/DB 등) 절대 빈 화면으로
    //        멈추지 않도록 각 단계를 개별 try/catch 로 감싸고, 무슨 일이 있어도
    //        runApp() 까지 진행한다. (전체 먹통/검은 화면 방지)
    try {
      await HanjaDict.instance.load();
    } catch (e) {
      debugPrint('HanjaDict load failed: $e');
    }
    try {
      await DbService.instance.open();
      // 앱을 다시 시작하면 항상 처음(빈) 작업 상태로 시작한다.
      await DbService.instance.clearAll();
    } catch (e) {
      debugPrint('DB init failed: $e');
    }
    try {
      await FamilySearchService.loadConfig();
    } catch (e) {
      debugPrint('FamilySearch config load failed: $e');
    }

    runApp(const ProviderScope(child: FamilySearchHelperApp()));
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}
