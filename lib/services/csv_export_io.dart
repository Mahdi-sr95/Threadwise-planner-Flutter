import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveOrShareCsv(String filename, String csvText) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csvText, flush: true);

  await Share.shareXFiles([XFile(file.path)], text: 'Study plan CSV');
}
