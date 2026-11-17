import 'dart:convert';

String encodeLuaStringList(Iterable<String> values) =>
    '{${values.map(_encodeLuaString).join(',')}}';

String _encodeLuaString(String value) {
  const firstPrintableAscii = 0x20; // 空格
  const lastPrintableAscii = 0x7e; // ~
  const doubleQuote = 0x22;
  const backslash = 0x5c;

  final result = StringBuffer('"');
  for (final byte in utf8.encode(value)) {
    final isPrintableAscii =
        byte >= firstPrintableAscii && byte <= lastPrintableAscii;
    final canWriteDirectly =
        isPrintableAscii && byte != doubleQuote && byte != backslash;

    if (canWriteDirectly) {
      result.writeCharCode(byte);
    } else {
      // 固定三位，避免转义后紧跟的数字被解释为同一个字节。
      final escapedByte = byte.toString().padLeft(3, '0');
      result.write('\\$escapedByte');
    }
  }
  result.write('"');
  return result.toString();
}
