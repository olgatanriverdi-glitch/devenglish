// Web dışı platformlarda kullanılmaz (flutter_tts kullanılır).
Future<void> sesDurdur() async {}

Future<void> konus(
  String metin, {
  required int konusmaci,
  required bool yavas,
}) async {}

Future<void> klipCal(
  String url, {
  required bool yavas,
  required int sureSn,
}) async {}

void klipDurdur() {}
