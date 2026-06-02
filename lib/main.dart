import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/hanja_dict.dart';
import 'services/db_service.dart';
import 'services/familysearch_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 자산 사전 / DB 사전 로딩
  await HanjaDict.instance.load();
  await DbService.instance.open();
  await FamilySearchService.loadConfig();

  runApp(const ProviderScope(child: FamilySearchHelperApp()));
}
