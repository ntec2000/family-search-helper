# 실제 족보 OCR 정답 대조 절차

이 문서는 실제 이미지의 인식 정확도를 임의로 추정하지 않고, 사람이 확인한 전사(정답)와 OCR 결과를 비교하기 위한 안내입니다.

## 준비

- 원본 이미지/PDF는 변경하지 않고 별도 보관합니다.
- OCR 결과를 JSON 파일로 준비합니다. 예: `local_ocr_results.json`
- **실제로 확인한** 인물과 필드만 `referencePersons`에 기록합니다. 예시는 형식 설명이며 실제 족보의 정답이라고 주장하지 않습니다.
- 사적인 족보 자료는 공개 GitHub 저장소에 커밋하지 마세요.

## JSON 입력 예시 (형식 설명용 가상 데이터)

```json
{
  "results": [
    {
      "columns": [
        {"text": "子甲 字仲明 甲子生", "heading": true},
        {"text": "配某氏 乙丑生", "heading": false}
      ]
    }
  ],
  "referencePersons": [
    {
      "nameHanja": "甲",
      "ja": "仲明",
      "birthDateLunar": "甲子",
      "spouseBirth": "乙丑"
    }
  ]
}
```

`results` 배열의 각 항목은 `text` 문자열 하나 또는 `columns` 배열을 사용합니다. `columns` 항목에는 `text` 문자열이 필수이고 `heading` 불리언은 선택 사항입니다. `heading`이 일부 열에만 지정된 경우 미지정 열은 `false`로 처리됩니다.

`referencePersons`는 선택 사항입니다. 현재 평가 코드는 `nameHanja`를 기준으로 파싱된 인물과 연결합니다. 정답 자료나 파싱 결과에서 동일한 한자 이름이 여러 명 발견되거나 해당 이름이 없으면 자동 연결하지 않고 `unresolvedNames`에 남깁니다. 정답에 입력하지 않은 필드는 점수 계산에서 제외됩니다.

비교 가능한 필드: `nameHanja`, `ja`, `ho`, `spouseHanja`, `spouseFather`, `birthDateLunar`, `deathDateLunar`, `spouseBirth`, `spouseDeath`.

**주의:** 인물 연결 자체가 `nameHanja`에 의존하므로 이름 일치 점수는 독립적인 인물 식별 정확도를 의미하지 않습니다. 동일 이름의 서로 다른 인물, 판독 불가능한 이름, 잘못 연결된 인물은 반드시 수작업으로 검토해야 합니다.

## 실행

Flutter/Dart 개발 환경에서 저장소 루트로 이동해 실행합니다.

```bash
flutter test test/actual_ocr_evaluation_test.dart --dart-define=OCR_RESULTS=local_ocr_results.json
```

파일 경로는 테스트 프로세스의 작업 디렉터리를 기준으로 해석됩니다. 실제 OCR 결과가 없을 때는 `OCR_RESULTS`를 지정하지 않고 기본 테스트만 실행할 수 있으나, 이 경우 실제 OCR 정확도는 측정하지 않습니다.

## 결과 확인

입력 파일 옆에 `local_ocr_results.json.evaluation.json` 보고서가 생성됩니다.

- `rawReferenceNameCoverage`: 각 OCR 열 내부에 정답 이름 문자열이 있는 비율입니다. 전체 OCR 글자 정확도가 아닙니다.
- `parsedReferenceNameCoverage`: 서로 다른 기준 이름 중 별도 인물로 파싱된 이름의 비율입니다. 같은 이름이 여러 번 등장해도 하나의 문자열로 계산하므로 인물 수 기준 인식률은 아닙니다.
- `embeddedSpouseNames`: 딸 등의 기록에 포함된 배우자 이름입니다. 별도 인물로 파싱되지 않았다면 인물 이름 인식 성공에 포함하지 않습니다.
- `referenceFieldEvaluation.fieldScores`: 제공한 정답 필드별 비교 수, 일치 수, 불일치 수입니다.
- `referenceFieldEvaluation.fieldMismatches`: 인물별 불일치 세부 내용입니다. `nameHanja`, `field`, `expected`, `actual`을 기록하며, **일치한 항목은 포함하지 않습니다.**
- `referenceFieldEvaluation.missingReferenceNames`: 정답 인물 목록에는 있지만 파싱 결과에서 발견되지 않은 이름입니다.
- `referenceFieldEvaluation.extraParsedNames`: 파싱 결과에만 나타난 이름 후보입니다. 잘못 읽힌 이름과 누락 이름을 임의로 짝짓지 않습니다.
- `referenceFieldEvaluation.unresolvedNames`: 이름이 없거나, 정답 자료 또는 파싱 결과에서 이름이 중복되어 자동 대조할 수 없는 인물입니다. 이름 앞뒤 공백은 비교 전에 제거합니다.
- `persons`, `regionsAssembled`: 수작업 검토를 위한 분석 결과입니다.

기준 이름은 입력한 `referencePersons`에서만 가져옵니다. 기준 이름이 없으면 이름 포함 비율은 `null`이며, 특정 페이지의 이름을 자동으로 대입하지 않습니다. 이 수치를 전체 족보 인식률로 해석하지 마세요. 본인·배우자의 출생·사망 필드가 바뀌거나 다른 인물의 기록이 섞였는지도 원문과 대조해야 합니다.

## 검증 원칙

1. 원본 및 기존 저장 데이터는 수정하지 않습니다.
2. OCR 출력과 정답 전사를 분리해서 관리합니다.
3. 이름·자·호·배우자·생몰 기록은 각 필드별로 확인합니다.
4. 인물 경계가 불확실하면 자동 확정하지 않고 검토 대상으로 남깁니다.
5. 실제 OCR 이미지/전사 자료가 없는 상태에서 정확도 수치를 발표하지 않습니다.
