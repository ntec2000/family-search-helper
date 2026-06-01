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

    for (final p in persons) {
      buf.writeln('0 @I${_safeId(p.id)}@ INDI');
      // NAME: hangul /hanja/
      final hangul = p.nameHangul.isEmpty ? '?' : p.nameHangul;
      final hanja = p.nameHanja.isEmpty ? '' : p.nameHanja;
      buf.writeln('1 NAME $hangul /$hanja/');
      buf.writeln('2 ROMN ${p.nameRoman}');
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
    }

    buf.writeln('0 TRLR');
    return buf.toString();
  }

  static String _safeId(String id) => id.replaceAll('-', '').substring(0, 8);
}
