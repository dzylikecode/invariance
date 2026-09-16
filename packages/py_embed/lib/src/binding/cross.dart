import 'dart:io';

import 'windows.dart' as win;
import 'posix.dart' as posix;

void initPy(String path) =>
    Platform.isWindows ? win.initPy(path) : posix.initPy(path);
