/// Rows as CSV (RFC 4180): a cell with a comma, quote or line break is quoted,
/// with its quotes doubled.
String toCsv(List<List<String>> rows) {
  String cell(String s) => s.contains(RegExp('[",\r\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  return rows.map((r) => r.map(cell).join(',')).join('\n');
}
