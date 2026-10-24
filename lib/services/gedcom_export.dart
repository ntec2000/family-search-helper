import '../models/person.dart';

/// GEDCOM 5.5.1 내보내기 (FamilySearch 호환)
class GedcomExport {
  static String toGedcom(List<Person> persons) {
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
      final raw = persons[i].id.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
      var candidate = 'I${raw.isEmpty ? 'person' : raw}';
      if (used.contains(candidate)) candidate = '${candidate}_${i + 1}';
      while (used.contains(candidate)) candidate = '${candidate}_';
      used.add(candidate);
      ids[persons[i].id] = candidate;
    }

    // Only link relationships backed by stored person IDs. Never infer family ties.
    final families = <String, ({String? father, String? mother, List<String> children})>{};
    final childFamily = <String, String>{};
    for (final child in persons) {
      final father = child.fatherId != child.id && ids.containsKey(child.fatherId)
          ? child.fatherId
          : null;
      final mother = child.motherId != child.id && ids.containsKey(child.motherId)
          ? child.motherId
          : null;
      if (father == null && mother == null) continue;
      final key = '${father ?? ''}|${mother ?? ''}';
      final family = families[key];
      if (family == null) {
        families[key] = (father: father, mother: mother, children: <String>[child.id]);
      } else {
        family.children.add(child.id);
      }
      childFamily[child.id] = key;
    }
    final familyIds = <String, String>{};
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
      if (surname.isNotEmpty && fullName.startsWith(surname)) {
        buf.writeln('1 NAME $given /$surname/');
      } else {
        buf.writeln('1 NAME ${fullName.isEmpty ? '?' : fullName}');
      }
      if (p.nameHanja.trim().isNotEmpty) {
        buf.writeln('1 NOTE 한자 이름: ${p.nameHanja.trim()}');
      }
      if (p.nameRoman.trim().isNotEmpty) {
        buf.writeln('1 NOTE 로마자 이름: ${p.nameRoman.trim()}');
      }
      buf.writeln('1 SEX ${p.gender}');

      if (p.birthDateSolar != null || p.birthDateLunar != null) {
        buf.writeln('1 BIRT');
        if (p.birthDateSolar != null) buf.writeln('2 DATE ${p.birthDateSolar}');
        if (p.birthPlace != null) buf.writeln('2 PLAC ${p.birthPlace}');
        if (p.birthDateLunar != null) buf.writeln('2 NOTE 음력: ${p.birthDateLunar}');
      }

      if (p.deathDateSolar != null || p.deathDateLunar != null) {
        buf.writeln('1 DEAT');
        if (p.deathDateSolar != null) buf.writeln('2 DATE ${p.deathDateSolar}');
        if (p.deathPlace != null) buf.writeln('2 PLAC ${p.deathPlace}');
        if (p.deathDateLunar != null) buf.writeln('2 NOTE 음력: ${p.deathDateLunar}');
      }

      if (p.burialPlace != null) {
        buf.writeln('1 BURI');
        buf.writeln('2 PLAC ${p.burialPlace}');
        if (p.burialOrientation != null) {
          buf.writeln('2 NOTE 좌향: ${p.burialOrientation}');
        }
      }

      if (p.ja != null) buf.writeln('1 NICK 字 ${p.ja}');
      if (p.ho != null) buf.writeln('1 NICK 號 ${p.ho}');
      if (p.bongwan != null) buf.writeln('1 NOTE 本貫: ${p.bongwan}');
      if (p.pa != null) buf.writeln('1 NOTE 派: ${p.pa}');
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
