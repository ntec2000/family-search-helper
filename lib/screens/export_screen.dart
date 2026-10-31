import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/person.dart';
import '../services/db_service.dart';
import '../services/gedcom_export.dart';
import '../services/ganzhi_year_label.dart';
import '../services/female_name_display.dart';
import '../services/spouse_parent_text.dart';
import '../services/gender_label.dart';
import '../services/familysearch_record.dart';
import '../services/familysearch_comparison_summary.dart';
import '../services/hanja_dict.dart';
import '../services/genealogy.dart';
import '../services/romanizer.dart';
import '../services/familysearch_service.dart';
import '../theme/traditional_theme.dart';
import '../widgets/couple_export_dialog.dart';
import '../widgets/familysearch_parent_link_dialog.dart';
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
      if (people.map((p) => p.id).toSet().length != people.length) {
        throw StateError('중복 인물 ID');
      }
      if (!mounted) return;
      final couples = await showDialog<List<(String, String)>>(
        context: context, builder: (_) => CoupleExportDialog(people: people));
      if (couples == null || !mounted) return;
      final json = const JsonEncoder.withIndent('  ').convert(
          FamilySearchRecord.document(people, reviewedCouples: couples));
      const filename = 'familysearch-records.json';
      await Share.shareXFiles([XFile.fromData(
          Uint8List.fromList(utf8.encode(json)),
          mimeType: 'application/json', name: filename)],
          fileNameOverrides: [filename]);
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('내보내기 전 확인: ${error.message}')));
      }
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
      if (list.map((p) => p.id).toSet().length != list.length) {
        throw StateError('중복 인물 ID');
      }
      if (!mounted) return;
      final couples = await showDialog<List<(String, String)>>(
        context: context,
        builder: (_) => CoupleExportDialog(people: list, formatLabel: 'GEDCOM'));
      if (couples == null || !mounted) return;
      final ged = GedcomExport.toGedcom(list, reviewedCouples: couples);
      final filename = 'family_${DateTime.now().millisecondsSinceEpoch}.ged';
      await Share.shareXFiles([
        XFile.fromData(Uint8List.fromList(utf8.encode(ged)),
            mimeType: 'text/plain', name: filename),
      ], fileNameOverrides: [filename], subject: '가족역사기록 GEDCOM');
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 전 확인: ${error.message}')),
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
        final dauRel = (p.relation ?? '').isNotEmpty ? p.relation! : '여성';
        final femaleName = FemaleNameDisplay.forPerson(p);
        final hasPersonalName = p.nameHangul.trim().isNotEmpty || p.nameHanja.trim().isNotEmpty;
        buf.writeln(div);
        buf.writeln('${i + 1}. $segaTag$dauRel (이름: $femaleName)');
        buf.writeln('  성(姓)    : ${np.surnameHangul} ${np.surnameHanja}');
        buf.writeln(hasPersonalName
            ? '  이름      : $femaleName${p.nameHangul.trim().isNotEmpty && p.nameHanja.trim().isNotEmpty ? ' ${p.nameHanja}' : ''}'
            : '  이름      : (이름 없음 → $femaleName)');
        buf.writeln('  성별      : 여');
        if ((p.birthDateSolar ?? p.birthDateLunar ?? '').isNotEmpty) {
          buf.writeln('  출생      : ${p.birthDateSolar ?? p.birthDateLunar}');
        }
        final birthGanzhi = GanzhiYearLabel.fromDate(p.birthDateLunar);
        if (birthGanzhi != null) buf.writeln('  출생 참고 : ${p.birthDateLunar} ($birthGanzhi)');
        if ((p.deathDateSolar ?? p.deathDateLunar ?? '').isNotEmpty) {
          buf.writeln('  사망      : ${p.deathDateSolar ?? p.deathDateLunar}');
        }
        final deathGanzhi = GanzhiYearLabel.fromDate(p.deathDateLunar);
        if (deathGanzhi != null) buf.writeln('  사망 참고 : ${p.deathDateLunar} ($deathGanzhi)');
        if ((p.spouseBirth ?? '').isNotEmpty) {
          final label = GanzhiYearLabel.fromDate(p.spouseBirth);
          buf.writeln('  남편 출생 : ${p.spouseBirth}${label == null ? '' : ' ($label)'}');
        }
        if ((p.spouseDeath ?? '').isNotEmpty) {
          final label = GanzhiYearLabel.fromDate(p.spouseDeath);
          buf.writeln('  남편 사망 : ${p.spouseDeath}${label == null ? '' : ' ($label)'}');
        }
        if ((p.spouseHanja ?? '').trim().isNotEmpty ||
            (p.spouseHangul ?? '').trim().isNotEmpty) {
          final spouseHanja = (p.spouseHanja ?? '').trim();
          final spouseHangul = (p.spouseHangul ?? '').trim();
          final reading = spouseHangul.isNotEmpty ? spouseHangul : dict.toHangul(spouseHanja);
          buf.writeln('  남편      : $reading $spouseHanja'
              '${(p.spouseBongwan ?? '').isNotEmpty ? '   [본관: ${p.spouseBongwan}]' : ''}');
        } else if ((p.spouseBongwan ?? '').isNotEmpty) {
          buf.writeln('  사위      : $femaleName의 남편 (이름 미상)   [지역: ${p.spouseBongwan}人]');
        }
        for (final parent in SpouseParentText.lines(p)) {
          buf.writeln('  $parent');
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
      buf.writeln('  성별      : ${genderLabel(p.gender)}');
      if (p.bongwan != null) {
        buf.writeln('  본관      : ${_kh(p.bongwan)}'
            '${p.pa != null ? '   派: ${p.pa}' : ''}');
      }
      if (p.ja != null) buf.writeln('  字(자)    : ${_kh(p.ja)}');
      if (p.ho != null) buf.writeln('  號(호)    : ${_kh(p.ho)}');
      buf.writeln('  출생      : ${p.birthDateSolar ?? p.birthDateLunar ?? '알 수 없음'}');
      final birthGanzhi = GanzhiYearLabel.fromDate(p.birthDateLunar);
      if (birthGanzhi != null) buf.writeln('  출생 참고 : ${p.birthDateLunar} ($birthGanzhi)');
      buf.writeln('  출생지    : ${p.birthPlace?.trim().isNotEmpty == true ? p.birthPlace : '알 수 없음'}');
      final deathDate = p.deathDateSolar ?? p.deathDateLunar ?? '';
      if (deathDate.isNotEmpty) {
        buf.writeln('  사망      : $deathDate');
        buf.writeln('  사망지    : ${p.deathPlace?.trim().isNotEmpty == true ? p.deathPlace : '알 수 없음'}');
      }
      final deathGanzhi = GanzhiYearLabel.fromDate(p.deathDateLunar);
      if (deathGanzhi != null) buf.writeln('  사망 참고 : ${p.deathDateLunar} ($deathGanzhi)');
      if (p.burialPlace != null) {
        final ori = p.burialOrientation != null ? ' (${p.burialOrientation})' : '';
        buf.writeln('  매장      : ${_kh(p.burialPlace)}$ori');
      }
      // ── 배우자 ──
      if ((p.spouseHanja ?? '').trim().isNotEmpty ||
          (p.spouseHangul ?? '').trim().isNotEmpty) {
        final h = (p.spouseHangul ?? '').trim();
        final hanja = (p.spouseHanja ?? '').trim();
        final display = h.isEmpty ? _kh(hanja) : '$h${hanja.isEmpty ? '' : ' ($hanja)'}';
        buf.writeln('  배우자    : $display'
            '${(p.spouseBongwan ?? '').isNotEmpty ? '   [본관: ${p.spouseBongwan}]' : ''}');
      }
      if ((p.spouseBirth ?? '').isNotEmpty) {
        final label = GanzhiYearLabel.fromDate(p.spouseBirth);
        buf.writeln('  배우자 생 : ${p.spouseBirth}${label == null ? '' : ' ($label)'}');
      }
      if ((p.spouseDeath ?? '').isNotEmpty) {
        final label = GanzhiYearLabel.fromDate(p.spouseDeath);
        buf.writeln('  배우자 졸 : ${p.spouseDeath}${label == null ? '' : ' ($label)'}');
      }
      if (p.marriageDate != null) buf.writeln('  결혼      : ${p.marriageDate}');
      // ── 처가(장인) 계열 — 아내 성씨를 붙여 표기 ──
      final ss = p.gender == 'M' ? Genealogy.spouseSurname(p.spouseHanja) : null;
      String inLawName(String? n) {
        if (n == null || n.isEmpty) return '';
        if (ss != null) {
          final fullName = Genealogy.surnamePrefixedName(n, ss.$1);
          final given = fullName.substring(ss.$1.length);
          return '$fullName (${ss.$2}${dict.toHangul(given)})';
        }
        return '$n (${dict.toHangul(n)})';
      }
      final father = (p.spouseFather ?? '').trim();
      final mother = (p.spouseMother ?? '').trim();
      if (father.isNotEmpty) {
        buf.writeln('  배우자 부친 : ${inLawName(father)}');
      }
      if (mother.isNotEmpty) {
        buf.writeln('  배우자 모친 : $mother');
      } else if (father.isNotEmpty) {
        buf.writeln('  배우자 모친 : ${inLawName(father)}의 부인 (이름 미상)');
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
      if (await DbService.instance.getConfig(FamilySearchService.pendingConfigKey(person.id)) == '1') {
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
    await DbService.instance.setConfig(FamilySearchService.personIdConfigKey(person.id), confirmedId);
    await DbService.instance.setConfig(FamilySearchService.pendingConfigKey(person.id), '0');
    if (!mounted) return;
    setState(() => _status = '확인된 FamilySearch ID를 저장했습니다. 자동 재등록 대상에서 제외됩니다.');
  }

  Future<void> _compareFamilySearchPerson() async {
    if (_busy) return;
    final people = await DbService.instance.listPersons();
    if (!mounted) return;
    if (people.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비교할 저장된 인물이 없습니다.')));
      return;
    }
    final person = await showDialog<Person>(context: context, builder: (ctx) =>
      SimpleDialog(title: const Text('비교할 앱 인물 선택'), children: [
        for (final p in people)
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, p),
              child: Text('${p.nameHangul.isNotEmpty ? p.nameHangul : p.nameHanja} · ${p.id}')),
      ]));
    if (person == null || !mounted) return;
    final savedId = await DbService.instance.getConfig(FamilySearchService.personIdConfigKey(person.id));
    if (!mounted) return;
    final controller = TextEditingController(text: savedId ?? '');
    final targetId = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('FamilySearch 인물 ID 입력'),
      content: TextField(controller: controller,
          decoration: const InputDecoration(labelText: '인물 ID', hintText: '예: ABCD-123')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        FilledButton(onPressed: () {
          final id = controller.text.trim();
          if (!RegExp(r'^[A-Za-z0-9-]{4,40}$').hasMatch(id)) return;
          Navigator.pop(ctx, id);
        }, child: const Text('조회')),
      ],
    ));
    controller.dispose();
    if (targetId == null || !mounted) return;
    if (!FamilySearchService.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('먼저 FamilySearch 연동과 Client ID를 설정하세요.')));
      return;
    }
    if (!FamilySearchService.isLoggedIn) {
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => const FamilySearchLoginScreen()));
      if (!mounted || !FamilySearchService.isLoggedIn) return;
    }
    setState(() { _busy = true; _status = '기존 인물 기록 조회 중...'; });
    final remote = await FamilySearchService.readPerson(targetId);
    if (!mounted) return;
    setState(() { _busy = false; _status = remote == null ? '조회 실패: ID, 로그인 또는 서버 상태를 확인하세요.' : '조회 완료: 기존 기록과 앱 자료를 비교하세요.'; });
    if (remote == null) return;
    const pretty = JsonEncoder.withIndent('  ');
    final remotePerson = Map<String, dynamic>.from((remote['persons'] as List).first as Map);
    final appPerson = FamilySearchRecord.person(person);
    final linkRequested = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('인물 비교 · $targetId'),
      content: SizedBox(width: 700, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('조회 결과와 앱 자료를 대조하세요. 이 화면은 기록을 수정하지 않습니다.'),
          const SizedBox(height: 12),
          const Text('FamilySearch 기존 기록', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final line in FamilySearchComparisonSummary.lines(remotePerson)) SelectableText(line),
          const SizedBox(height: 12),
          const Text('앱에서 검토한 자료', style: TextStyle(fontWeight: FontWeight.bold)),
          for (final line in FamilySearchComparisonSummary.lines(appPerson)) SelectableText(line),
          ExpansionTile(title: const Text('전체 자료 보기'), children: [
            const Text('FamilySearch 조회 내용'), SelectableText(pretty.convert(remote)),
            const Text('앱 자료'), SelectableText(pretty.convert(appPerson)),
          ]),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('닫기')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('같은 인물로 ID 연결')),
      ],
    ));
    if (linkRequested != true || !mounted) return;
    final currentId = await DbService.instance.getConfig(FamilySearchService.personIdConfigKey(person.id));
    final pending = await DbService.instance.getConfig(FamilySearchService.pendingConfigKey(person.id));
    if (!mounted) return;
    if (pending == '1' || (currentId != null && currentId.isNotEmpty &&
        currentId.toUpperCase() != targetId.toUpperCase())) {
      setState(() => _status = 'ID 연결 중지: 기존 ID 또는 미확인 등록 기록을 먼저 확인하세요.');
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('동일 인물 연결 확인'),
      content: Text('${person.nameHangul.isNotEmpty ? person.nameHangul : person.nameHanja}와 '
          '$targetId가 같은 사람임을 원본과 대조해 확인했습니까? '
          '앱에 ID만 저장하며 FamilySearch 기록은 변경하지 않습니다.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인 후 저장')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    try {
      await DbService.instance.bindConfirmedFamilySearchId(personId: person.id,
          targetId: targetId, sandbox: FamilySearchService.useSandbox);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _status = 'ID 연결 중지: ${error.message}');
      return;
    }
    if (!mounted) return;
    setState(() => _status = '확인한 인물 ID를 앱에 저장했습니다. FamilySearch 기록은 변경하지 않았습니다.');
  }

  Future<void> _syncFamilySearch() async {
    if (_busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(FamilySearchService.useSandbox
            ? 'FamilySearch 테스트 서버 등록 확인'
            : 'FamilySearch 신규 인물 등록 확인'),
        content: const Text(
          '${FamilySearchService.useSandbox ? '현재 테스트 서버에만 등록하며 실제 가계도에는 반영되지 않습니다. ' : ''}'
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
      final pending = await DbService.instance.getConfig(FamilySearchService.pendingConfigKey(person.id));
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
      final pending = await DbService.instance.getConfig(FamilySearchService.pendingConfigKey(p.id));
      if (pending == '1') {
        uncertain = true;
        break;
      }
      final savedId = await DbService.instance.getConfig(FamilySearchService.personIdConfigKey(p.id));
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
      await DbService.instance.setConfig(FamilySearchService.pendingConfigKey(p.id), '1');
      final id = await FamilySearchService.createPerson(p);
      if (id != null) {
        await DbService.instance.setConfig(FamilySearchService.personIdConfigKey(p.id), id);
        await DbService.instance.setConfig(FamilySearchService.pendingConfigKey(p.id), '0');
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
                subtitle: const Text('가계도 파일 · 서비스별 가져오기와 자료 전달 범위 확인'),
                trailing: const Icon(Icons.download),
                onTap: _exportGedcom,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text('FamilySearch에서 GEDCOM을 올린 뒤 기존 인물과 비교해 주세요. '
                  '공유 패밀리 트리로 옮길 때 출처·메모·사진은 자동 이전되지 않을 수 있으므로 '
                  '원문을 보관하고 해당 기록에서 직접 확인하세요.'),
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
            const Text('② FamilySearch 직접 등록',
                style: TextStyle(fontWeight: FontWeight.bold, color: HanjiColors.ju)),
            const SizedBox(height: 8),
            Card(child: ListTile(
              leading: const Icon(Icons.compare_arrows, color: HanjiColors.muk),
              title: const Text('인물 ID로 기존 기록 비교'),
              subtitle: const Text(FamilySearchService.useSandbox
                  ? '테스트 서버 조회 · 기존 기록과 앱 자료 비교'
                  : '기존 기록과 앱 자료 비교'),
              onTap: _busy ? null : _compareFamilySearchPerson,
            )),
            Card(child: ListTile(
              leading: const Icon(Icons.account_tree_outlined, color: HanjiColors.muk),
              title: const Text('부모·자녀 연결 준비'),
              subtitle: const Text('ID와 근거 검토 · 전송 및 연결 기능은 준비 중'),
              onTap: _busy ? null : () => showDialog<void>(context: context,
                  builder: (_) => const FamilySearchParentLinkDialog()),
            )),
            if (FamilySearchService.enabled)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_upload, color: HanjiColors.ju),
                  title: const Text(FamilySearchService.useSandbox
                      ? 'FamilySearch 테스트 서버 등록'
                      : 'FamilySearch 인물 등록'),
                  subtitle: Text(!FamilySearchService.isConfigured
                      ? 'Client ID 미입력 — 설정에서 입력하세요'
                      : (FamilySearchService.isLoggedIn
                          ? (FamilySearchService.useSandbox
                              ? '로그인됨 — 테스트 서버만 사용'
                              : '로그인됨 — 인물 등록 가능')
                          : 'FamilySearch 로그인 필요')),
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
                  subtitle: Text('설정에서 켤 수 있습니다. 현재 테스트 서버 전용입니다.'),
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
