/// 기록되지 않은 장소는 지명으로 추정하지 않는다.
String placeDisplay(String? value) {
  final place = (value ?? '').trim();
  return place.isEmpty ? '미상' : place;
}
