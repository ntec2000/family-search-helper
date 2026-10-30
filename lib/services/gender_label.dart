/// 검토되지 않은 성별을 임의로 확정하지 않는다.
String genderLabel(String gender) => switch (gender) {
  'M' => '남',
  'F' => '여',
  _ => '미상',
};
