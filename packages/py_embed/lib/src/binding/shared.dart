import 'dart:ffi';

import 'package:ffi/ffi.dart' as ffi;

import 'shared.g.dart' as g;
import 'api.dart';

extension PyStatusExt on g.PyStatus {
  bool get isException => $singleApi.PyStatus_Exception(this) != 0; // $singleApi 切断循环链
  String get message => err_msg.cast<ffi.Utf8>().toDartString();
  void guard() {
    if (isException) {
      throw this;
    }
  }
}

extension ApiExt on BaseApi {
  // TODO last error
  int getLastError() => PyErr_Occurred() != nullptr ? 0 : 0;
}
