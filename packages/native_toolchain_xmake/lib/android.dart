import 'package:code_assets/code_assets.dart';
import 'package:path/path.dart' as p;

class AndroidTool {
  final CodeConfig codeConfig;

  AndroidTool(this.codeConfig);

  String? get ndk {
    final compiler = codeConfig.cCompiler?.compiler;
    return compiler != null
        ? p.normalize(p.join(compiler.toFilePath(), '../../../../../..'))
        : null;
  }

  String? get bin {
    final compiler = codeConfig.cCompiler?.compiler;
    return compiler != null
        ? p.normalize(p.dirname(compiler.toFilePath()))
        : null;
  }
}
