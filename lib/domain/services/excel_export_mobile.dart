import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShareFile(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$filename';
  await File(path).writeAsBytes(bytes);
  await Share.shareXFiles(
    [XFile(path)],
    text: 'Exportado desde Control de Clase',
  );
}
