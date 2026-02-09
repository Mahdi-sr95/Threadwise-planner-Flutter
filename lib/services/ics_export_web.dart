import 'dart:convert';
import 'dart:html' as html;

Future<void> saveOrShareIcs(String filename, String icsText) async {
  final bytes = utf8.encode(icsText);
  final blob = html.Blob([bytes], 'text/calendar;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';

  html.document.body!.children.add(a);
  a.click();
  a.remove();

  html.Url.revokeObjectUrl(url);
}
