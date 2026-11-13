/// Escapes a value for use inside a quoted attribute.
String escapeAttribute(String value) {
  const amp =
      '&'
      'amp;';
  const quot =
      '&'
      'quot;';
  const lt =
      '&'
      'lt;';
  const gt =
      '&'
      'gt;';
  return value
      .replaceAll('&', amp)
      .replaceAll('"', quot)
      .replaceAll('<', lt)
      .replaceAll('>', gt);
}

/// Escapes a text run.
String escapeText(String value) {
  const amp =
      '&'
      'amp;';
  const lt =
      '&'
      'lt;';
  const gt =
      '&'
      'gt;';
  return value.replaceAll('&', amp).replaceAll('<', lt).replaceAll('>', gt);
}

String unescape(String value) {
  const lt =
      '&'
      'lt;';
  const gt =
      '&'
      'gt;';
  const quot =
      '&'
      'quot;';
  const amp =
      '&'
      'amp;';
  const apos =
      '&'
      '#39;';
  return value
      .replaceAll(lt, '<')
      .replaceAll(gt, '>')
      .replaceAll(quot, '"')
      .replaceAll(apos, "'")
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      )
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (match) => String.fromCharCode(int.parse(match.group(1)!)),
      )
      .replaceAll(amp, '&');
}
