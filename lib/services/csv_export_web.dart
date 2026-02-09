import 'dart:convert';
import 'dart:html' as html;

/// Web implementation used by conditional import in [CsvExportService].
/// Must match: Future<void> saveOrShareCsv(String filename, String csvText)
Future<void> saveOrShareCsv(String filename, String csvText) async {
  final bytes = utf8.encode(csvText);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body!.children.add(a);
  a.click();
  a.remove();

  html.Url.revokeObjectUrl(url);
}
