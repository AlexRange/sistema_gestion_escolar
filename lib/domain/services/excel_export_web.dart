// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> saveAndShareFile(List<int> bytes, String filename) async {
  final blob = html.Blob([bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrlFromBlob(blob);
  // ignore: unused_local_variable
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
