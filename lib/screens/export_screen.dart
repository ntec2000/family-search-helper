import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../services/gedcom_export.dart';
import '../services/familysearch_record.dart';
import '../services/hanja_dict.dart';
import '../services/genealogy.dart';
import '../services/romanizer.dart';
import '../services/familysearch_service.dart';
import '../theme/traditional_theme.dart';
import 'familysearch_login_screen.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});
  @override
  State<ExportScreen> createState() => _State();
}

class _State extends State<ExportScreen> {
  bool _busy = false;
  String _status = '';

  Future<void> _exportFamilySearchJson() async {
    try {
      final people = await DbService.instance.listPersons();
      final json = const JsonEncoder.withIndent('  ').convert(
          FamilySearchRecord.document(people));
      const filename = 'familysearch-records.json';
      await Share.shareXFiles([XFile.fromData(
          Uint8List.fromList(utf8.encode(json)),
          mimeType: 'application/json', name: filename)],
          fileNameOverrides: [filename]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('FamilySearch 자료를 내보내지 못했습니다. 다시 시도하세요.')));
      }
    }
  }

  Future<void> _exportGedcom() async {
    try {
      final list = await DbService.instance.listPersons();
      final ged = GedcomExport.toGedcom(list);
      final filename = 'family_${DateTime.now().millisecondsSinceEpoch}.ged';
      await Share.shareXFiles([
        XFile.fromData(Uint8List.fromList(utf8.encode(ged)),
            mimeType: 'text/plain', name: filename),
      ], fileNameOverrides: [filename], subject: '가족역사기록 GEDCOM');
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인물 ID가 중복되어 내보내기를 중단했습니다. 원본 자료를 확인해 주세요.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GEDCOM 파일 내보내기에 실패했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  /// 한자 → "한글 (한자)" 표기. 한자가 비어있으면 빈 문자열.
  // #3 한자(한글) 표기. 한자가 비어있으면 빈 문자열.
  static String _kh(String? hanja) {
    if (hanja == null || hanja.trim().isEmpty) return '';
    return HanjaDict.instance.annotate(hanja.trim());
  }

  /// v2.3 — 첨부 족보를 인식·정리한 형식의 정렬 텍스트.
  /// 처가(장인) 계열·사위·딸(○씨) 포함, FamilySearch 입력 항목 대응.
  String _buildText(List<Person> list) {
    const div = '────────────────────';
    final dict = HanjaDict.instance;
    final buf = StringBuffer();
    buf.writeln('가족역사기록 (FamilySearch 입력용 정리)');
    buf.writeln('총 ${list.length}명');
    buf.writeln();
    for (var i = 0; i < list.length; i++) {
      final p = list[i];
      final segaTag = p.sega != null ? '[${p.sega}世] ' : '';

      // ── 딸(女): 이름 없음 → 가문 성씨 + 씨, 표기된 인물은 남편(사위) ──
      if (p.gender == 'F') {
        final np = Genealogy.split(
            hanja: '', hangul: '',
            surnameHanja: p.surnameHanja, surnameHangul: p.surnameHangul,
            isFemale: true);
        final dauRel = (p.relation ?? '').isNotEmpty ? p.relation! : '딸';
        buf.writeln(div);
        buf.writeln('${i + 1}. $segaTag$dauRel (이름: ${np.singleHangul})');
        buf.writeln('  성(姓)    : ${np.surnameHangul} ${np.surnameHanja}');
        buf.writeln('  이름      : (이름 없음 → ${np.singleHangul})');
        buf.writeln('  성별      : 여');
        if ((p.spouseHanja ?? '').isNotEmpty) {
          buf.writeln('  사위      : ${dict.toHangul(p.spouseHanja!)} ${p.spouseHanja}'
              '${(p.spouseBongwan ?? '').isNotEmpty ? '   [본관: ${p.spouseBongwan}]' : ''}');
        } else if ((p.spouseBongwan ?? '').isNotEmpty) {
          buf.writeln('  사위      : ${np.singleHangul}의 남편 (이름 미상)   [지역: ${p.spouseBongwan}人]');
        }
        if ((p.note ?? '').isNotEmpty) buf.writeln('  특이사항  : ${p.note}');
        buf.writeln();
        continue;
      }

      // ── 아들(子, 본손) ──
      final np = Genealogy.split(
          hanja: p.nameHanja,
          hangul: p.nameHangul.isNotEmpty
              ? p.nameHangul
              : dict.toHangul(p.nameHanja),
          surnameHanja: p.surnameHanja,
          surnameHangul: p.surnameHangul);
      final roman = p.nameRoman.isNotEmpty
          ? p.nameRoman
          : Romanizer.romanizeName(np.surnameHangul + np.givenHangul);
      buf.writeln(div);
      buf.writeln('${i + 1}. $segaTag${p.nameHanja} (이름: ${np.surnameHangul}${np.givenHangul})');
      buf.writeln('  성(姓)    : ${np.surnameHangul} ${np.surnameHanja} (${np.surnameRoman})');
      buf.writeln('  이름      : ${np.givenHangul} ${np.givenHanja}'
          '${np.givenRoman.isNotEmpty ? ' (${np.givenRoman})' : ''}');
      buf.writeln('  로마자    : $roman');
      buf.writeln('  성별      : 남');
      if (p.bongwan != null) {
        buf.writeln('  본관      : ${_kh(p.bongwan)}'
            '${p.pa != null ? '   派: ${p.pa}' : ''}');
      }
      if (p.ja != null) buf.writeln('  字(자)    : ${_kh(p.ja)}');
      if (p.ho != null) buf.writeln('  號(호)    : ${_kh(p.ho)}');
      buf.writeln('  출생      : ${p.birthDateSolar ?? p.birthDateLunar ?? '알 수 없음'}');
      buf.writeln('  출생지    : ${p.birthPlace?.trim().isNotEmpty == true ? p.birthPlace : '알 수 없음'}');
      final deathDate = p.deathDateSolar ?? p.deathDateLunar ?? '';
      if (deathDate.isNotEmpty) {
        buf.writeln('  사망      : $deathDate');
        buf.writeln('  사망지    : ${p.deathPlace?.trim().isNotEmpty == true ? p.deathPlace : '알 수 없음'}');
      }
      if (p.burialPlace != null) {
        final ori = p.burialOrientation != null ? ' (${p.burialOrientation})' : '';
        buf.writeln('  매장      : ${_kh(p.burialPlace)}$ori');
      }
      // ── 배우자 ──
      if ((p.spouseHanja ?? '').isNotEmpty) {
        buf.writeln('  배우자    : ${_kh(p.spouseHanja)}'
            '${(p.spouseBongwan ?? '').isNotEmpty ? '   [본관: ${p.spouseBongwan}]' : ''}');
        if ((p.spouseBirth ?? '').isNotEmpty) buf.writeln('  배우자 생 : ${p.spouseBirth}');
        if ((p.spouseDeath ?? '').isNotEmpty) buf.writeln('  배우자 졸 : ${p.spouseDeath}');
      }
      if (p.marriageDate != null) buf.writeln('  결혼      : ${p.marriageDate}');
      // ── 처가(장인) 계열 — 아내 성씨를 붙여 표기 ──
      final ss = Genealogy.spouseSurname(p.spouseHanja);
      String inLawName(String? n) {
        if (n == null || n.isEmpty) return '';
        if (ss != null) return '${ss.$1}$n (${ss.$2}${dict.toHangul(n)})';
        return '$n (${dict.toHangul(n)})';
      }
      if ((p.spouseFather ?? '').isNotEmpty) {
        buf.writeln('  장인      : ${inLawName(p.spouseFather)}');
        buf.writeln('  장모      : ${p.spouseMother ?? '${inLawName(p.spouseFather)}의 부인'}');
      }
      if ((p.spouseGrandfather ?? '').isNotEmpty) {
        buf.writeln('  장인의 부 : ${inLawName(p.spouseGrandfather)}');
      }
      if ((p.spouseGreatGrandfather ?? '').isNotEmpty) {
        buf.writeln('  처증조    : ${inLawName(p.spouseGreatGrandfather)}');
      }
      if ((p.spouseMaternalGrandfather ?? '').isNotEmpty) {
        buf.writeln('  처외조    : ${_kh(p.spouseMaternalGrandfather)}');
      }
      if (p.childrenNote != null) buf.writeln('  자녀      : ${p.childrenNote}');
      if (p.sonsInLawNote != null) buf.writeln('  사위      : ${p.sonsInLawNote}');
      if (p.inLawsNote != null) buf.writeln('  사돈      : ${p.inLawsNote}');
      if (p.inLawsSpouseNote != null) buf.writeln('  사돈부인  : ${p.inLawsSpouseNote}');
      if ((p.note ?? '').isNotEmpty) buf.writeln('  특이사항  : ${p.note}');
      if ((p.reasonStatement ?? '').isNotEmpty) {
        buf.writeln('  근거      : ${p.reasonStatement}');
      }
      buf.writeln();
    }
    return buf.toString();
  }
  void _previewText() async {
    final list = await DbService.instance.listPersons();
    final text = _buildText(list);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('내보내기 미리보기'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(text,
                style: const TextStyle(fontSize: 13, height: 1.6)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기')),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Share.share(text, subject: '가족역사기록');
            },
            icon: const Icon(Icons.share),
            label: const Text('공유'),
          ),
        ],
      ),
    );
  }

  Future<void> _resolvePendingUpload() async {
    if (_busy) return;
    final people = await DbService.instance.listPersons();
    Person? pendingPerson;
    for (final person in people) {
      if (await DbService.instance.getConfig('fs_upload_pending_${person.id}') == '1') {
        pendingPerson = person;
        break;
      }
    }
    if (!mounted) return;
    if (pendingPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('확인이 필요한 등록 기록이 없습니다.')),
      );
      return;
    }
    final person = pendingPerson;
    final controller = TextEditingController();
    final confirmedId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('FamilySearch 등록 기록 확인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('로컬 ID: ${person.id}'),
            Text('이름: ${person.nameHangul.isNotEmpty ? person.nameHangul : person.nameHanja}'),
            const SizedBox(height: 12),
            const Text('FamilySearch에서 동일 인물의 등록을 직접 확인한 경우에만 '
                '해당 인물 ID를 입력하세요. 확인하지 못했다면 취소하세요.'),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: '확인된 FamilySearch 인물 ID'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (!RegExp(r'^[A-Za-z0-9-]{4,40}$').hasMatch(value)) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('확인된 ID 저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmedId == null || !mounted) return;
    await DbService.instance.setConfig('fs_person_id_${person.id}', confirmedId);
    await DbService.instance.setConfig('fs_upload_pending_${person.id}', '0');
    if (!mounted) return;
    setState(() => _status = '확인된 FamilySearch ID를 저장했습니다. 자동 재등록 대상에서 제외됩니다.');
  }

  Future<void> _syncFamilySearch() async {
    if (_busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('FamilySearch 신규 인물 등록 확인'),
        content: const Text(
          '이 작업은 기존 인물과의 중복 여부를 자동 확인하지 않고 신규 인물을 생성합니다. '
          '이 앱에서 등록에 성공한 인물은 저장된 FamilySearch ID를 기준으로 재등록하지 않습니다. '
          '다른 기기나 기존 FamilySearch 가계도의 중복 인물은 확인하지 못합니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('신규 등록 진행'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    if (!FamilySearchService.isLoggedIn) {
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => const FamilySearchLoginScreen()));
      if (!mounted || !FamilySearchService.isLoggedIn) return;
    }
    setState(() {
      _busy = true;
      _status = 'FamilySearch 로 인물 동기화 중...';
    });
    final list = await DbService.instance.listPersons();
    // Check all unresolved requests before sending any new person.
    for (final person in list) {
      final pending = await DbService.instance.getConfig('fs_upload_pending_${person.id}');
      if (pending == '1') {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _status = '동기화 중지: 미확인 등록 기록이 있습니다. '
              '인물 ID ${person.id} / '
              '이름 ${person.nameHangul.isNotEmpty ? person.nameHangul : person.nameHanja}. '
              'FamilySearch에서 기존 등록 여부를 먼저 확인해 주세요. '
              '자동 재등록하지 않습니다.';
        });
        return;
      }
    }
    int ok = 0, fail = 0, skipped = 0, nameless = 0, alreadyRegistered = 0;
    bool uncertain = false;
    for (final p in list) {
      final pending = await DbService.instance.getConfig('fs_upload_pending_${p.id}');
      if (pending == '1') {
        uncertain = true;
        break;
      }
      final savedId = await DbService.instance.getConfig('fs_person_id_${p.id}');
      if (savedId != null && savedId.isNotEmpty) {
        alreadyRegistered++;
        continue;
      }
      if (p.nameHangul.trim().isEmpty &&
          p.nameHanja.trim().isEmpty &&
          p.nameRoman.trim().isEmpty) {
        nameless++;
        continue;
      }
      if ((p.deathDateSolar ?? '').trim().isEmpty &&
          (p.deathDateLunar ?? '').trim().isEmpty) {
        skipped++;
        continue;
      }
      await DbService.instance.setConfig('fs_upload_pending_${p.id}', '1');
      final id = await FamilySearchService.createPerson(p);
      if (id != null) {
        await DbService.instance.setConfig('fs_person_id_${p.id}', id);
        await DbService.instance.setConfig('fs_upload_pending_${p.id}', '0');
        ok++;
        if (mounted) setState(() => _status = '진행 중: $ok명 등록 / 전체 ${list.length}명');
      } else {
        fail++;
        uncertain = true;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = '완료: 신규 $ok명 / 기존 등록 제외 $alreadyRegistered명 / '
          '사망 확인 불가 제외 $skipped명 / 이름 없음 제외 $nameless명 / 실패 $fail명'
          '${uncertain ? ' / 등록 결과 불명확: 자동 재시도 중지' : ''}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내보내기 / 동기화')),
      body: SafeArea(child: Stack(children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
          children: [
            const Text('① 파일로 내보내기 (로그인 불필요)',
                style: TextStyle(fontWeight: FontWeight.bold, color: HanjiColors.ju)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_tree, color: HanjiColors.muk),
                title: const Text('GEDCOM 5.5.1 (.ged)'),
                subtitle: const Text('FamilySearch · Ancestry · MyHeritage 호환'),
                trailing: const Icon(Icons.download),
                onTap: _exportGedcom,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.text_snippet, color: HanjiColors.muk),
                title: const Text('텍스트 (수동 입력용)'),
                subtitle: const Text('정렬된 텍스트 · 字/배우자 한글 표기 · 복사·공유'),
                trailing: const Icon(Icons.visibility),
                onTap: _previewText,
              ),
            ),
            const SizedBox(height: 8),
            Card(child: ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('FamilySearch 항목별 자료 (.json)'),
              subtitle: const Text('성·이름·한자·생졸·출처·검토한 가족관계'),
              onTap: _exportFamilySearchJson,
            )),
            const SizedBox(height: 32),
            const Text('② FamilySearch 직접 동기화',
                style: TextStyle(fontWeight: FontWeight.bold, color: HanjiColors.ju)),
            const SizedBox(height: 8),
            if (FamilySearchService.enabled)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload, color: HanjiColors.ju),
                  title: const Text('FamilySearch.org 직접 업로드'),
                  subtitle: Text(!FamilySearchService.isConfigured
                      ? 'Client ID 미입력 — 설정에서 입력하세요'
                      : (FamilySearchService.isLoggedIn
                          ? '로그인됨 — 인물 등록 가능'
                          : 'LDS 회원 계정 로그인 필요')),
                  trailing: const Icon(Icons.upload),
                  onTap: (_busy || !FamilySearchService.isConfigured)
                      ? null
                      : _syncFamilySearch,
                ),
              )
            else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.cloud_off, color: HanjiColors.muk),
                  title: Text('FamilySearch 연동 꺼짐'),
                  subtitle: Text('설정 → FamilySearch 연동에서 켜면 사용할 수 있습니다.'),
                ),
              ),
            if (FamilySearchService.enabled)
              ListTile(
                leading: const Icon(Icons.fact_check),
                title: const Text('미확인 등록 기록 검토'),
                subtitle: const Text('FamilySearch에서 실제 등록을 확인한 경우에만 ID 저장'),
                onTap: _busy ? null : _resolvePendingUpload,
              ),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_status,
                    style: const TextStyle(color: HanjiColors.ju)),
              ),
          ],
        ),
        if (_busy)
          Container(
            color: Colors.black54,
            child: const Center(
                child: CircularProgressIndicator(color: HanjiColors.hanji)),
          ),
      ])),
    );
  }
}
