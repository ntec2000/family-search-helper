import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/person.dart';
import 'db_service.dart';

/// FamilySearch.org 공식 API 연동 (OAuth 2.0)
///
/// ⚠️ 사용 전 준비:
///   1) https://www.familysearch.org/developers 에서 무료 개발자 계정 등록
///   2) 앱 등록 후 Client ID 발급 (Redirect URI: familysearchhelper://oauth)
///   3) 아래 [clientId] 상수에 입력
///   4) 사용자는 LDS 회원 계정으로 로그인
///
/// 본 앱은 FamilySearch 가 없어도 GEDCOM 으로 수동 업로드 가능합니다.
/// 로그인은 "직접 동기화"를 원할 때만 선택적으로 사용합니다.
class FamilySearchService {
  // Client ID 는 설정 화면에서 사용자가 직접 입력합니다.
  // https://www.familysearch.org/developers 에서 무료 발급.
  static String clientId = '';
  static const String redirectUri = 'familysearchhelper://oauth';

  /// 사용자가 설정에서 'FamilySearch 연동'을 켰는지 여부 (기본 꺼짐 = 추출 전용 모드)
  static bool enabled = false;

  /// 앱 시작 시 저장된 설정 로드
  static Future<void> loadConfig() async {
    enabled = (await DbService.instance.getConfig('fs_enabled')) == '1';
    clientId = (await DbService.instance.getConfig('fs_client_id')) ?? '';
  }

  /// 설정 저장
  static Future<void> saveConfig(
      {required bool isEnabled, required String id}) async {
    enabled = isEnabled;
    clientId = id.trim();
    await DbService.instance.setConfig('fs_enabled', isEnabled ? '1' : '0');
    await DbService.instance.setConfig('fs_client_id', clientId);
  }

  /// 연동 모드가 실제로 사용 가능한 상태인지 (켜짐 + Client ID 입력됨)
  static bool get isConfigured => enabled && clientId.isNotEmpty;

  // Sandbox(개발) vs Production
  static const bool useSandbox = true;
  static String get _base => useSandbox
      ? 'https://api-integ.familysearch.org'
      : 'https://api.familysearch.org';
  static String get _identBase => useSandbox
      ? 'https://identbeta.familysearch.org'
      : 'https://ident.familysearch.org';

  static String? _accessToken;
  static String? get accessToken => _accessToken;
  static bool get isLoggedIn => _accessToken != null;

  /// OAuth 2.0 Authorization URL 생성
  static Uri authorizationUrl() {
    return Uri.parse('$_identBase/cis-web/oauth2/v3/authorization').replace(
      queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'scope': 'openid profile email',
      },
    );
  }

  /// Authorization Code → Access Token 교환
  static Future<bool> exchangeCode(String code) async {
    try {
      final client = HttpClient();
      final req =
          await client.postUrl(Uri.parse('$_identBase/cis-web/oauth2/v3/token'));
      req.headers
          .set('Content-Type', 'application/x-www-form-urlencoded');
      req.write('grant_type=authorization_code'
          '&code=$code'
          '&client_id=$clientId'
          '&redirect_uri=${Uri.encodeComponent(redirectUri)}');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        _accessToken = json['access_token'] as String?;
        return _accessToken != null;
      }
      debugPrint('FS token error: ${resp.statusCode} $body');
      return false;
    } catch (e) {
      debugPrint('FS exchange error: $e');
      return false;
    }
  }

  static void logout() {
    _accessToken = null;
  }

  /// 현재 사용자 정보
  static Future<Map<String, dynamic>?> currentUser() async {
    return _get('/platform/users/current');
  }

  /// 인물 등록 (gx JSON 포맷)
  /// FamilySearch GEDCOM-X 표준 사용.
  static Future<String?> createPerson(Person p) async {
    final body = {
      'persons': [
        {
          'living': false,
          'gender': {
            'type': p.gender == 'M'
                ? 'http://gedcomx.org/Male'
                : 'http://gedcomx.org/Female'
          },
          'names': [
            {
              'nameForms': [
                {
                  'fullText':
                      '${p.nameHangul} ${p.nameHanja} ${p.nameRoman}'.trim(),
                  'parts': [
                    if (p.nameHangul.isNotEmpty)
                      {'type': 'http://gedcomx.org/Given', 'value': p.nameHangul},
                  ],
                }
              ]
            }
          ],
          'facts': [
            if (p.birthDateSolar != null || p.birthPlace != null)
              {
                'type': 'http://gedcomx.org/Birth',
                'date': {'original': p.birthDateSolar ?? p.birthDateLunar ?? ''},
                'place': {'original': p.birthPlace ?? ''},
              },
            if (p.deathDateSolar != null || p.deathPlace != null)
              {
                'type': 'http://gedcomx.org/Death',
                'date': {'original': p.deathDateSolar ?? p.deathDateLunar ?? ''},
                'place': {'original': p.deathPlace ?? ''},
              },
            if (p.burialPlace != null)
              {
                'type': 'http://gedcomx.org/Burial',
                'place': {'original': p.burialPlace!},
              },
          ],
        }
      ]
    };
    final result = await _post('/platform/tree/persons', body);
    if (result == null) return null;
    final persons = (result['persons'] as List?) ?? [];
    if (persons.isNotEmpty) return persons.first['id'] as String?;
    return null;
  }

  // ─── HTTP 헬퍼 ──────────────────────────────────────────

  static Future<Map<String, dynamic>?> _get(String path) async {
    if (_accessToken == null) return null;
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('$_base$path'));
      req.headers.set('Authorization', 'Bearer $_accessToken');
      req.headers.set('Accept', 'application/x-gedcomx-v1+json');
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode == 200) {
        return jsonDecode(body) as Map<String, dynamic>;
      }
      debugPrint('FS GET error: ${resp.statusCode} $body');
      return null;
    } catch (e) {
      debugPrint('FS GET exception: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _post(
      String path, Map<String, dynamic> body) async {
    if (_accessToken == null) return null;
    try {
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('$_base$path'));
      req.headers.set('Authorization', 'Bearer $_accessToken');
      req.headers.set('Content-Type', 'application/x-gedcomx-v1+json');
      req.headers.set('Accept', 'application/x-gedcomx-v1+json');
      req.write(jsonEncode(body));
      final resp = await req.close();
      final respBody = await resp.transform(utf8.decoder).join();
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(respBody) as Map<String, dynamic>;
      }
      debugPrint('FS POST error: ${resp.statusCode} $respBody');
      return null;
    } catch (e) {
      debugPrint('FS POST exception: $e');
      return null;
    }
  }
}
