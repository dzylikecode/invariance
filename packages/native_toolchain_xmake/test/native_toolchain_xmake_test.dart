// import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';
// import 'package:test/test.dart';

// void main() {
//   group('NativeToolchainXmake', () {
//     const toolchain = NativeToolchainXmake();

//     test('hasXmake returns bool', () async {
//       final ok = await toolchain.hasXmake();
//       expect(ok, isA<bool>());
//     });

//     test('ensureXmakeInstalled check-only returns structured result', () async {
//       final result = await toolchain.ensureXmakeInstalled(installIfMissing: false);
//       expect(result.isAvailable, isA<bool>());
//       expect(result.wasInstalled, isFalse);
//       expect(result.method, isNull);
//       expect(result.message, isNotEmpty);
//     });
//   });
// }
