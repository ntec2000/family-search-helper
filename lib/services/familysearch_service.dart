import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/person.dart';
import 'db_service.dart';
import 'familysearch_record.dart';

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
    final client = http.Client();
    try {
      final resp = await client.post(
        Uri.parse('$_identBase/cis-web/oauth2/v3/token'), body: {
        'grant_type': 'authorization_code',
        'code': code.trim(),
        'client_id': clientId,
        'redirect_uri': redirectUri,
      });
      final body = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        _accessToken = json['access_token'] as String?;
        return _accessToken != null;
      }
      debugPrint('FS token error: HTTP ${resp.statusCode}');
      return false;
    } catch (e) {
      debugPrint('FS exchange failed');
      return false;
    } finally {
      client.close();
    }
  }

  static void logout() {
    _accessToken = null;
  }

  /// 현재 사용자 정보
  static Future<Map<String, dynamic>?> currentUser() async {
    return _get('/platform/users/current');
  }

  /// 사용자가 입력한 인물 ID의 현재 기록을 조회한다. 조회만 수행한다.
  static Future<Map<String, dynamic>?> readPerson(String id) async {
    final value = id.trim();
    if (!RegExp(r'^[A-Za-z0-9-]{4,40}$').hasMatch(value)) return null;
    final result = await _get('/platform/tree/persons/${Uri.encodeComponent(value)}');
    final persons = result?['persons'];
    if (persons is! List || persons.length != 1 || persons.first is! Map ||
        (persons.first as Map)['id'] != value) {
      return null;
    }
    return result;
  }

  /// 인물 등록 (gx JSON 포맷)
  /// FamilySearch GEDCOM-X 표준 사용.
  static Future<String?> createPerson(Person p) async {
    // Never create a nameless remote record from incomplete OCR data.
    if (p.nameHangul.trim().isEmpty &&
        p.nameHanja.trim().isEmpty &&
        p.nameRoman.trim().isEmpty) {
      return null;
    }
    // Without a confirmed death record, do not upload a possibly living person
    // as deceased. A manual review workflow is required for uncertain cases.
    if ((p.deathDateSolar ?? '').trim().isEmpty &&
        (p.deathDateLunar ?? '').trim().isEmpty) {
      return null;
    }
    final body = {'persons': [FamilySearchRecord.person(p)]};
    final result = await _post('/platform/tree/persons', body);
    if (result == null) return null;
    final persons = (result['persons'] as List?) ?? [];
    if (persons.isNotEmpty) return persons.first['id'] as String?;
    return null;
  }

  // ─── HTTP 헬퍼 ──────────────────────────────────────────

  static Future<Map<String, dynamic>?> _get(String path) async {
    if (_accessToken == null) return null;
    final client = http.Client();
    try {
      final resp = await client.get(Uri.parse('$_base$path'), headers: {
        'Authorization': 'Bearer $_accessToken',
        'Accept': 'application/x-gedcomx-v1+json',
      });
      final body = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200) {
        return jsonDecode(body) as Map<String, dynamic>;
      }
      debugPrint('FS GET error: HTTP ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('FS GET request failed');
      return null;
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>?> _post(
      String path, Map<String, dynamic> body) async {
    if (_accessToken == null) return null;
    final client = http.Client();
    try {
      final resp = await client.post(Uri.parse('$_base$path'), headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/x-gedcomx-v1+json',
        'Accept': 'application/x-gedcomx-v1+json',
      }, body: jsonEncode(body));
      final respBody = utf8.decode(resp.bodyBytes);
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (respBody.trim().isNotEmpty) {
          final decoded = jsonDecode(respBody);
          if (decoded is Map<String, dynamic> && decoded['persons'] is List &&
              (decoded['persons'] as List).isNotEmpty) {
            return decoded;
          }
        }
        final location = resp.headers['location'];
        if (location != null) {
          final segments = Uri.parse(location).pathSegments;
          final index = segments.lastIndexOf('persons');
          if (index >= 0 && index + 1 < segments.length &&
              segments[index + 1].isNotEmpty) {
            return {'persons': [{'id': segments[index + 1]}]};
          }
        }
        return null;
      }
      debugPrint('FS POST error: HTTP ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('FS POST request failed');
      return null;
    } finally {
      client.close();
    }
  }
}
