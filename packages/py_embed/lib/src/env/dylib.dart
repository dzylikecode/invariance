import 'loader.dart';
import 'env_args.dart';

final dllPath = getPyDllPathFromVenvSync();
final dll = openEx(dllPath);
