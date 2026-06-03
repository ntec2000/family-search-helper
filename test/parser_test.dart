import 'package:flutter_test/flutter_test.dart';
import 'package:family_search_helper/services/jokbo_parser.dart';
import 'package:family_search_helper/models/person.dart';
import 'package:family_search_helper/services/genealogy.dart';
import 'package:family_search_helper/services/lunar_service.dart';

void main() {
  // 주의: HanjaDict 는 rootBundle 의존이라 순수 Dart 테스트에서는 로드되지 않는다.
  // 따라서 한글 음 변환(toHangul)은 항등(원문 유지)으로 동작하므로,
  // 아래 검증은 한자/구조 필드 위주로 단언한다. (Genealogy 의 성씨 맵은 사전 비의존)

  group('만세력', () {
    test('乙卯 연도 추정', () {
      final years = LunarService.estimateYearsFromGanzhi('乙卯');
      expect(years, contains(1915));
      expect(years, contains(1975));
    });

    test('양력 → 음력 + 干支', () {
      final r = LunarService.solarToLunar(DateTime(1929, 11, 7));
      expect(r['ganzhi_year'], '己巳');
      expect(r['animal'], '蛇');
    });

    test('干支 유효성', () {
      expect(LunarService.isValidGanzhi('乙卯'), true);
      expect(LunarService.isValidGanzhi('XY'), false);
    });
  });

  group('가문 성씨 자동 감지', () {
    test('固城李氏 → 李/이', () {
      final clan = Genealogy.detectClanSurname('固城李氏 思菴公派譜 二十世 子昃');
      expect(clan, isNotNull);
      expect(clan!.$1, '李');
      expect(clan.$2, '이');
    });

    test('처가 성씨 추출 (原州邊氏 → 邊/변)', () {
      final ss = Genealogy.spouseSurname('原州邊氏');
      expect(ss, isNotNull);
      expect(ss!.$1, '邊');
      expect(ss.$2, '변');
    });
  });

  group('족보 파서 (子在源 단순 표기)', () {
    test('출생·사망·배우자·장인·묘', () {
      // 墓 는 본인부(配 앞)에 위치
      final text =
          '子在源 字古元 乙未十一月十日生 乙丑九月十二日卒 墓楊口郡東面 配密陽朴氏父重建';
      final p = JokboParser.parse(text).first;
      expect(p.gender, 'M');
      expect(p.nameHanja, '在源');
      expect(p.ja, '古元');
      expect(p.birthDateLunar, contains('乙未'));
      expect(p.deathDateLunar, contains('乙丑'));
      expect(p.spouseHanja, contains('朴氏'));
      expect(p.spouseFather, '重建');
      expect(p.burialPlace, contains('楊口郡'));
    });
  });

  group('v2.3 시뮬레이션 — 固城李氏 思菴公派譜 224면', () {
    // 본 페이지를 평문(세로→가로 정렬)으로 선형화한 OCR 모사 텍스트
    const page = '固城李氏 思菴公派譜 '
        '子昃 二十世 字汝明 甲子生 墓固城南山 '
        '配原州邊氏 父國聖 祖同知 曾祖判官尙 外祖文化柳承春 '
        '子格 二十一世 壬辰生 '
        '子核 二十一世 乙未生 '
        '女權頭 安東人 '
        '女金免傑 金海人 '
        '女李集 全州人';

    final list = JokboParser.parse(page);

    test('인물 수 (아들 3 + 딸 3 = 6)', () {
      expect(list.length, 6);
    });

    test('[20世] 昃 — 配(처가) 계열이 배우자 필드로 귀속', () {
      final p = list.firstWhere((e) => e.nameHanja == '昃');
      expect(p.gender, 'M');
      expect(p.sega, 20);
      expect(p.ja, '汝明');
      expect(p.birthDateLunar, contains('甲子'));
      expect(p.burialPlace, contains('固城南山'));
      // 본관 + 氏
      expect(p.spouseBongwan, '原州');
      expect(p.spouseHanja, contains('邊氏'));
      // 처가 계열
      expect(p.spouseFather, '國聖'); // 장인 (변국성)
      expect(p.spouseGrandfather, '同知'); // 장인의 부
      expect(p.spouseGreatGrandfather, '判官尙'); // 처증조
      expect(p.spouseMaternalGrandfather, '文化柳承春'); // 처외조
      // 본인 성씨는 가문 성(李/이) 상속
      expect(p.surnameHanja, '李');
      expect(p.surnameHangul, '이');
    });

    test('[21世] 格 — 단순 干支生 + 가문 성씨 상속', () {
      final p = list.firstWhere((e) => e.nameHanja == '格');
      expect(p.gender, 'M');
      expect(p.birthDateLunar, contains('壬辰'));
      expect(p.surnameHanja, '李'); // 이격
      expect(p.surnameHangul, '이');
    });

    test('女 항목 = 사위(남편), 딸은 이름 없이 가문 성(이씨)', () {
      final daughters = list.where((e) => e.gender == 'F').toList();
      expect(daughters.length, 3);
      for (final d in daughters) {
        expect(d.nameHanja, ''); // 딸 본인은 이름 없음
        expect(d.surnameHanja, '李'); // 아버지(가문) 성 → 이씨
      }
      final kim = daughters.firstWhere((e) => e.spouseHanja == '金免傑');
      expect(kim.spouseBongwan, '金海'); // 사위 본관 (金海人)
      final kwon = daughters.firstWhere((e) => e.spouseHanja == '權頭');
      expect(kwon.spouseBongwan, '安東');
      final lee = daughters.firstWhere((e) => e.spouseHanja == '李集');
      expect(lee.spouseBongwan, '全州');
    });
  });

  group('v2.4 전체 페이지 시뮬레이션 — 固城李氏 思菴公派譜 224면', () {
    const page = '固城李氏 思菴公派譜 '
        '子 四 昃 二十世 字良甫 丁未生 庚申八月三日卒 '
        '配原州邊氏 壬戌生 甲子十月二十八日卒 父國聖 祖同知 曾祖判官尙 外祖文化柳承春 '
        '子 格 二十一世 字君平 壬辰生 配豊壤趙氏 癸巳生 父永復 '
        '子 聖甲 二十二世 甲子生 '
        '子 核 二十一世 字君實 丁酉生 忌三月五日 墓白石面鶴洞 '
        '配坡平尹氏 乙巳生 父光岳 祖東憶 曾祖通政道經 外祖濟州高 '
        '女 權頭 '
        '子 顯五 二十二世 字行之 庚午生 配原州元氏 甲戌生 父載億 '
        '女 權龜壽 '
        '女 李集 安東人 '
        '子 承烈 二十三世 字聖模 辛丑生 配務安朴氏 癸卯生 父基豊 祖奎秀 曾祖師元 外祖丁若萬 '
        '子 二 承勳 二十三世 出系顯龍后 '
        '女 安東人 '
        '女 全州人 '
        '子 賢東 二十四世 字致安 癸酉生 庚午十二月十六日卒 墓謹峴壬坐合窆 '
        '配交河盧氏 丁亥生 忌四月十三日 父愼 '
        '子 炳吉 二十五世 '
        '子 二 炳旭 出系寅東后 '
        '子 三 炳烈 '
        '子 四 炳直 '
        '女 金免傑 金海人 '
        '女 尹兢秀';

    final list = JokboParser.parse(page);
    Person byName(String n) => list.firstWhere((e) => e.nameHanja == n);

    test('전체 인물 수 = 19 (아들 12 + 딸 7)', () {
      expect(list.length, 19);
      expect(list.where((e) => e.gender == 'M').length, 12);
      expect(list.where((e) => e.gender == 'F').length, 7);
    });

    test('[20世] 昃 — 字·생졸·世·配 처가 계열', () {
      final p = byName('昃');
      expect(p.sega, 20);
      expect(p.ja, '良甫');
      expect(p.birthDateLunar, contains('丁未'));
      expect(p.deathDateLunar, contains('庚申'));
      expect(p.spouseBongwan, '原州');
      expect(p.spouseHanja, contains('邊氏'));
      expect(p.spouseBirth, contains('壬戌'));
      expect(p.spouseDeath, contains('甲子'));
      expect(p.spouseFather, '國聖');
      expect(p.spouseGrandfather, '同知');
      expect(p.spouseGreatGrandfather, '判官尙');
      expect(p.spouseMaternalGrandfather, '文化柳承春');
      expect(p.surnameHanja, '李');
    });

    test('[21世] 格 — 世·단순 干支生·성씨 상속', () {
      final p = byName('格');
      expect(p.sega, 21);
      expect(p.birthDateLunar, contains('壬辰'));
      expect(p.spouseFather, '永復');
      expect(p.surnameHanja, '李');
      expect(p.surnameHangul, '이');
    });

    test('[21世] 核 — 忌(연도미상)·墓·처가 계열', () {
      final p = byName('核');
      expect(p.birthDateLunar, contains('丁酉'));
      expect(p.deathDateLunar, contains('忌'));
      expect(p.burialPlace, contains('白石面'));
      expect(p.spouseFather, '光岳');
      expect(p.spouseGrandfather, '東憶');
      expect(p.spouseGreatGrandfather, '通政道經');
      expect(p.spouseMaternalGrandfather, '濟州高');
    });

    test('[23世] 承勳 — 出系 특이사항(이름은 承勳, 出 미포함)', () {
      final p = byName('承勳');
      expect(p.note, isNotNull);
      expect(p.note, contains('出系'));
      expect(p.note, contains('顯龍'));
      expect(p.surnameHanja, '李');
    });

    test('[25世] 炳旭 — 出系 寅東后', () {
      final p = byName('炳旭');
      expect(p.note, contains('寅東'));
      // 다른 25세 아들들도 정상 인식
      expect(list.any((e) => e.nameHanja == '炳吉'), true);
      expect(list.any((e) => e.nameHanja == '炳烈'), true);
      expect(list.any((e) => e.nameHanja == '炳直'), true);
    });

    test('[24世] 賢東 — 卒·墓(좌향·합폄)', () {
      final p = byName('賢東');
      expect(p.deathDateLunar, contains('庚午'));
      expect(p.burialPlace, contains('謹峴'));
      expect(p.spouseFather, '愼'); // 노신 (단자 이름)
    });

    test('女 = 사위 + 본관 분리, 딸은 이름 없이 가문 성(이씨)', () {
      final daughters = list.where((e) => e.gender == 'F').toList();
      expect(daughters.length, 7);
      for (final d in daughters) {
        expect(d.nameHanja, '');
        expect(d.surnameHanja, '李'); // 이씨
      }
      // 사위 이름 + 본관
      expect(daughters.firstWhere((e) => e.spouseHanja == '權頭').spouseBongwan, isNull);
      expect(daughters.firstWhere((e) => e.spouseHanja == '李集').spouseBongwan, '安東');
      expect(daughters.firstWhere((e) => e.spouseHanja == '金免傑').spouseBongwan, '金海');
      expect(daughters.firstWhere((e) => e.spouseHanja == '尹兢秀').spouseHanja, '尹兢秀');
      // 사위 이름 미상(본관만): 安東人 / 全州人 → spouseHanja null
      final nameless = daughters.where((e) => e.spouseHanja == null).toList();
      expect(nameless.length, 2);
      final bongwans = nameless.map((e) => e.spouseBongwan).toSet();
      expect(bongwans.contains('安東'), true);
      expect(bongwans.contains('全州'), true);
    });
  });

}
