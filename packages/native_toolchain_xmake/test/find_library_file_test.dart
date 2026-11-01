import 'dart:io';

import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('xmake_library_test_');
  });
  tearDown(() => directory.delete(recursive: true));

  Future<String> create(String name) async {
    final file = File(p.join(directory.path, name));
    await file.create();
    return file.path;
  }

  test('Static archives are selected beside stale shared libraries', () async {
    await create('libmujoco.so.3.12.0');
    final archive = await create('libmujoco.a');
    expect(
      await findLibraryFile('libmujoco.a', directory.path, kind: .static),
      archive,
    );
  });

  test('Missing static archives never resolve to shared libraries', () async {
    await create('libmujoco.so.3.12.0');
    await create('libmujoco.a.bak');
    await expectLater(
      findLibraryFile('libmujoco.a', directory.path, kind: .static),
      throwsA(
        isA<FileSystemException>().having(
          (error) => error.path,
          'path',
          p.join(directory.path, 'libmujoco.a'),
        ),
      ),
    );
  });

  test('Windows static libraries never resolve to DLLs', () async {
    await create('mujoco.dll');
    await expectLater(
      findLibraryFile('mujoco.lib', directory.path, kind: .static),
      throwsA(isA<FileSystemException>()),
    );
    final library = await create('mujoco.lib');
    expect(
      await findLibraryFile('mujoco.lib', directory.path, kind: .static),
      library,
    );
  });

  test('Unversioned shared libraries take precedence', () async {
    await create('libmujoco.so.3.12.0');
    final library = await create('libmujoco.so');
    expect(
      await findLibraryFile('libmujoco.so', directory.path, kind: .shared),
      library,
    );
  });

  test('Linux shared libraries accept numeric version suffixes', () async {
    await create('libmujoco.a');
    await create('libmujoco_extra.so');
    await create('libmujoco.so.bak');
    final library = await create('libmujoco.so.3.12.0');
    expect(
      await findLibraryFile('libmujoco.so', directory.path, kind: .shared),
      library,
    );
  });

  test('macOS shared libraries accept versions before the extension', () async {
    await create('libmujoco.a');
    await create('libmujoco_extra.dylib');
    final library = await create('libmujoco.3.12.0.dylib');
    expect(
      await findLibraryFile('libmujoco.dylib', directory.path, kind: .shared),
      library,
    );
  });

  test('Shared library searches reject unrelated files', () async {
    for (final name in [
      'libmujoco.a',
      'libmujoco_extra.so',
      'libmujoco.so.bak',
      'libmujoco.so.3.bak',
      'libmujoco_extra.dylib',
      'libmujoco.backup.dylib',
    ]) {
      await create(name);
    }
    for (final name in ['libmujoco.so', 'libmujoco.dylib']) {
      await expectLater(
        findLibraryFile(name, directory.path, kind: .shared),
        throwsA(isA<FileSystemException>()),
      );
    }
  });

  test('Missing install directories report the requested library', () async {
    await expectLater(
      findLibraryFile(
        'libmujoco.so',
        p.join(directory.path, 'missing'),
        kind: .shared,
      ),
      throwsA(isA<FileSystemException>()),
    );
  });
}
