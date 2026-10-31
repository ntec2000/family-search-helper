import '../models/person.dart';
import 'unknown_spouse_name.dart';

/// GEDCOM 5.5.1 내보내기 (FamilySearch 호환)
class GedcomExport {
  static String toGedcom(List<Person> persons,
      {List<(String, String)> reviewedCouples = const []}) {
    bool hasValue(String? value) => value?.trim().isNotEmpty == true;
    final buf = StringBuffer();
    buf.writeln('0 HEAD');
    buf.writeln('1 SOUR FamilySearchHelper');
    buf.writeln('2 VERS 1.0');
    buf.writeln('2 NAME 가족역사기록 도우미');
    buf.writeln('1 GEDC');
    buf.writeln('2 VERS 5.5.1');
    buf.writeln('2 FORM LINEAGE-LINKED');
    buf.writeln('1 CHAR UTF-8');

    // GEDCOM XREF는 파일 안에서 유일해야 하며 짧은 ID도 안전하게 처리한다.
    final ids = <String, String>{};
    final used = <String>{};
    for (var i = 0; i < persons.length; i++) {
      if (ids.containsKey(persons[i].id)) throw StateError('Duplicate person ID');
      final raw = persons[i].id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
      var candidate = 'I${raw.isEmpty ? 'person' : raw}';
      if (used.contains(candidate)) candidate = '${candidate}_${i + 1}';
      while (used.contains(candidate)) {
        candidate = '${candidate}_';
      }
      used.add(candidate);
      ids[persons[i].id] = candidate;
    }

    // Only link relationships backed by stored person IDs. Never infer family ties.
    final families = <(String?, String?), ({String? father, String? mother, List<String> children})>{};
    final childFamily = <String, (String?, String?)>{};
    for (final child in persons) {
      if (child.fatherId == child.id || child.motherId == child.id) {
        throw StateError('인물 ${child.id}이 자신의 부모로 지정되어 있습니다.');
      }
      if (child.fatherId != null && child.fatherId == child.motherId &&
          ids.containsKey(child.fatherId)) {
        throw StateError('같은 인물이 아버지와 어머니로 지정되어 있습니다.');
      }
      final father = child.fatherId != child.id && ids.containsKey(child.fatherId)
          ? child.fatherId
          : null;
      final mother = child.motherId != child.id && ids.containsKey(child.motherId)
          ? child.motherId
          : null;
      if (father == null && mother == null) continue;
      final key = (father, mother);
      final family = families[key];
      if (family == null) {
        families[key] = (father: father, mother: mother, children: <String>[child.id]);
      } else {
        family.children.add(child.id);
      }
      childFamily[child.id] = key;
    }
    // 부부 관계는 사용자가 검토한 ID만 포함한다. 성별 미상은 자동 배치하지 않는다.
    final byId = {for (final person in persons) person.id: person};
    final reviewed = <(String, String)>{};
    for (final (a, b) in reviewedCouples) {
      final first = byId[a];
      final second = byId[b];
      if (a.isEmpty || b.isEmpty || a == b || first == null || second == null) {
        throw StateError('부부 관계의 인물 ID를 확인하세요.');
      }
      if (!((first.gender == 'M' && second.gender == 'F') ||
          (first.gender == 'F' && second.gender == 'M'))) {
        throw StateError('GEDCOM 부부 역할에 대한 성별 확인이 필요합니다.');
      }
      final father = first.gender == 'M' ? a : b;
      final mother = first.gender == 'F' ? a : b;
      if (!reviewed.add((father, mother))) throw StateError('중복 부부 관계');
      final key = (father, mother);
      families.putIfAbsent(key, () => (father: father, mother: mother, children: <String>[]));
    }
    final familyIds = <(String?, String?), String>{};
    var familyIndex = 0;
    for (final key in families.keys) {
      familyIds[key] = 'F${++familyIndex}';
    }
    final spouseFamilies = <String, List<String>>{};
    for (final entry in families.entries) {
      final familyId = familyIds[entry.key]!;
      for (final parentId in <String?>[entry.value.father, entry.value.mother]) {
        if (parentId != null) {
          spouseFamilies.putIfAbsent(parentId, () => <String>[]).add(familyId);
        }
      }
    }

    for (final p in persons) {
      buf.writeln('0 @${ids[p.id]}@ INDI');
      // GEDCOM NAME uses /surname/, not /Hanja/.
      // Only separate a surname when it was explicitly recorded.
      final fullName = p.nameHangul.trim();
      final surname = (p.surnameHangul ?? '').trim();
      final given = surname.isNotEmpty && fullName.startsWith(surname)
          ? fullName.substring(surname.length).trim()
          : fullName;
      if (surname.isNotEmpty) {
        buf.writeln('1 NAME $given /$surname/');
      } else {
        final fallback = fullName.isEmpty ? p.nameHanja.trim() : fullName;
        buf.writeln('1 NAME ${fallback.isEmpty ? '?' : fallback}');
      }
      if (p.nameHanja.trim().isNotEmpty) {
        buf.writeln('1 NOTE 한자 이름: ${p.nameHanja.trim()}');
      }
      if (p.nameRoman.trim().isNotEmpty) {
        buf.writeln('1 NOTE 로마자 이름: ${p.nameRoman.trim()}');
      }
      buf.writeln('1 SEX ${p.gender}');

      if (hasValue(p.birthDateSolar) || hasValue(p.birthDateLunar) ||
          hasValue(p.birthPlace)) {
        buf.writeln('1 BIRT');
        if (hasValue(p.birthDateSolar)) buf.writeln('2 DATE ${p.birthDateSolar}');
        if (hasValue(p.birthPlace)) buf.writeln('2 PLAC ${p.birthPlace}');
        if (hasValue(p.birthDateLunar)) buf.writeln('2 NOTE 음력: ${p.birthDateLunar}');
      }

      if (hasValue(p.deathDateSolar) || hasValue(p.deathDateLunar) ||
          hasValue(p.deathPlace)) {
        buf.writeln('1 DEAT');
        if (hasValue(p.deathDateSolar)) buf.writeln('2 DATE ${p.deathDateSolar}');
        if (hasValue(p.deathPlace)) buf.writeln('2 PLAC ${p.deathPlace}');
        if (hasValue(p.deathDateLunar)) buf.writeln('2 NOTE 음력: ${p.deathDateLunar}');
      }

      if (hasValue(p.burialPlace)) {
        buf.writeln('1 BURI');
        buf.writeln('2 PLAC ${p.burialPlace}');
        if (hasValue(p.burialOrientation)) {
          buf.writeln('2 NOTE 좌향: ${p.burialOrientation}');
        }
      } else if (hasValue(p.burialOrientation)) {
        buf.writeln('1 NOTE 묘 좌향: ${p.burialOrientation}');
      }

      if (p.ja != null) buf.writeln('1 NICK 字 ${p.ja}');
      if (p.ho != null) buf.writeln('1 NICK 號 ${p.ho}');
      if (p.bongwan != null) buf.writeln('1 NOTE 本貫: ${p.bongwan}');
      if (p.pa != null) buf.writeln('1 NOTE 派: ${p.pa}');
      if (p.gender == 'M' && UnknownSpouseName.hasSpouseEvidence(p) && !UnknownSpouseName.hasPersonalNameCandidate(p)) {
        final label = UnknownSpouseName.wifeDisplayName(p);
        if (label != null) {
          buf.writeln('1 NOTE 아내 표시명(실제 개인 이름 아님): $label');
        }
      }
      for (final entry in <String, String?>{
        '배우자': p.spouseHanja, '배우자 한글': p.spouseHangul,
        '배우자 본관': p.spouseBongwan,
        '배우자 출생': p.spouseBirth, '배우자 사망': p.spouseDeath,
        '배우자 부친': p.spouseFather, '배우자 모친': p.spouseMother,
        '배우자 조부': p.spouseGrandfather,
        '배우자 증조부': p.spouseGreatGrandfather,
        '배우자 외조부': p.spouseMaternalGrandfather,
        '특이사항': p.note, '근거': p.reasonStatement,
        '족보 원문': p.rawText, 'PDF 페이지': p.sourcePageNumber?.toString(),
      }.entries) {
        if (entry.value?.isNotEmpty == true) {
          buf.writeln('1 NOTE ${entry.key}: ${entry.value!.replaceAll(RegExp(r'[\r\n]+'), ' ')}');
        }
      }
      if (p.gender == 'F' && p.nameHangul.isEmpty && p.nameHanja.isEmpty) {
        buf.writeln('1 NOTE 개인 이름 미상, 성씨만 기록됨');
      }
      if (p.sega != null) buf.writeln('1 NOTE ${p.sega}世');
      final parentFamily = childFamily[p.id];
      if (parentFamily != null) {
        buf.writeln('1 FAMC @${familyIds[parentFamily]}@');
      }
      for (final familyId in spouseFamilies[p.id] ?? const <String>[]) {
        buf.writeln('1 FAMS @$familyId@');
      }
    }

    for (final entry in families.entries) {
      buf.writeln('0 @${familyIds[entry.key]}@ FAM');
      final father = entry.value.father;
      final mother = entry.value.mother;
      if (father != null) buf.writeln('1 HUSB @${ids[father]}@');
      if (mother != null) buf.writeln('1 WIFE @${ids[mother]}@');
      for (final child in entry.value.children) {
        buf.writeln('1 CHIL @${ids[child]}@');
      }
    }

    buf.writeln('0 TRLR');
    return buf.toString();
  }

}
