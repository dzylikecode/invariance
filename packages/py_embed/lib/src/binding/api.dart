import 'dart:io';

import 'windows_3_8_20.dart' as windows_3_8_20;
import 'posix_3_8_20.dart' as posix_3_8_20;
import 'windows_3_9_25.dart' as windows_3_9_25;
import 'posix_3_9_25.dart' as posix_3_9_25;
import 'windows_3_10_21.dart' as windows_3_10_21;
import 'posix_3_10_21.dart' as posix_3_10_21;
import 'shared.g.dart' as shared;
import '../env/env_args.dart';

final api = getApi();

abstract class PlatformBaseApi {
  void initPy(String path);
}

abstract interface class BaseApi
    implements shared.NativeLibrary, PlatformBaseApi;

BaseApi getApi() =>
    switch ((pyVersion.major, pyVersion.minor, pyVersion.patch)) {
      (3, 8, _) when Platform.isWindows => windows_3_8_20.Api(pyDll),
      (3, 8, _) when !Platform.isWindows => posix_3_8_20.Api(pyDll),
      (3, 9, _) when Platform.isWindows => windows_3_9_25.Api(pyDll),
      (3, 9, _) when !Platform.isWindows => posix_3_9_25.Api(pyDll),
      (3, 10, _) when Platform.isWindows => windows_3_10_21.Api(pyDll),
      (3, 10, _) when !Platform.isWindows => posix_3_10_21.Api(pyDll),
      _ => throw UnimplementedError('$pyVersion is not supported now'),
    };
