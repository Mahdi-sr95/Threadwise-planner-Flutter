import 'dart:convert';
import 'dart:html' as html;

void downloadCsvWeb({required String csv, required String fileName}) {
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body!.children.add(a);
  a.click();
  a.remove();

  html.Url.revokeObjectUrl(url);
}
