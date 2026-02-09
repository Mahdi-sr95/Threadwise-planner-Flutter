import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveOrShareIcs(String filename, String icsText) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(icsText, flush: true);

  await Share.shareXFiles([
    XFile(file.path),
  ], text: 'ThreadWise Planner - ICS export');
}
