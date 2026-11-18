import 'dart:convert';
import 'dart:io';

import 'package:embed/embed.dart';

void main() {
  stdout.write(utf8.decode(Assets.file1Txt.bytes));
}
