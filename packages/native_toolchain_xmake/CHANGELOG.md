## Unreleased

- **feature**: add the `dart_native 1.0.0` xmake rule package for native library preparation, package installation, and final export selection with linker GC. Default to version-pinned Git sources; the custom `local_source` option selects the checkout's rule sources.
- **change**: pass `keep_symbols` as a Lua table literal string and deserialize it in the link rule. Native symbol selection comes from the Dart binding mapping.
- **breaking**: require `symbolsToKeep` when linking. Resolve missing usage records to the full binding mapping in Dart; xmake no longer supplies a default symbol list.
- **breaking**: use one target for build and link. Static builds install the archive, shared builds without symbols install the full shared package, and shared links with symbols trim a static package into the final library.
- **docs**: document shared-rule routing, immutable version-to-commit mappings, and explicit local development. Cover the remote source path with the template adapter example in CI.

---

- **功能**：新增 `dart_native 1.0.0` xmake 规则包，负责原生库准备、包安装，以及最终导出选择和 linker GC。默认使用版本固定的 Git 源码，自定义 `local_source` 选项显式选择 checkout 中的规则源码。
- **变更**：`keep_symbols` 改为 Lua table literal 字符串，由 link 规则反序列化；原生符号选择来自 Dart binding mapping。
- **变更**：link 时必须传入 `symbolsToKeep`。没有使用记录时由 Dart 选择完整 binding mapping，xmake 不再提供默认符号列表。
- **变更**：build/link 共用一个 target。static build 安装归档，无符号列表的 shared build 安装完整动态包，有符号列表的 shared link 将静态包链接为裁剪后的动态库。
- **文档**：说明共享规则路由、不可变的版本到 commit 映射，以及显式本地开发方式；CI 通过 template adapter 示例覆盖远程源码路径。

## 0.1.0

- **update**: bump `native_toolchain_c` to `^0.19.6` to fix incorrect decoding of UTF-8 output from `vswhere` on systems with a Chinese locale.
- **breaking**: rename `LinkModeOption` to `LinkHookMode` and `linkModeOption` to `linkHook`. The values `.static`, `.dynamic`, and `.byPreference` are now `.always`, `.never`, and `.auto`, respectively.
- **feature**: bundle an agent skill for packaging dynamic libraries, tree shaking, and troubleshooting common issues.

---

- **更新**: native_toolchain_c: ^0.19.6, 修复了中文环境下 vswhere 输出 utf-8 被解析错误的问题
- **变更**：`LinkModeOption` 改名为 `LinkHookMode`，`linkModeOption` 改为 `linkHook`。`.static`、`.dynamic`、`.byPreference` 分别改为 `.always`、`.never`、`.auto`。
- **功能**：Agent Skill，覆盖动态库打包、tree-shaking 和常见排错。

## 0.0.10

- **fix**: look up static archives in link mode.

---

- **修复**： link 模式下，需要寻找的是静态库而不是动态库

## 0.0.9

- **fix**: detect cross-compilation when the host and target have the same operating system but different architectures.

---

- **修复**：即使是同系统，但是架构不同也是交叉编译

## 0.0.8

- **feature**: add the `linkOption` field so users can choose whether to enable tree shaking.

---

- **功能**：添加 linkOption 字段，让用户决定是否启用 tree-shake

## 0.0.7

- **update**: bump `code_assets` to `^2.0.0`.

---

- **更新**: code_assets: ^2.0.0

## 0.0.6

- **fix**: export `library.dart` by default.

---

- **修复**：默认导出 library.dart

## 0.0.5

- **change**: align the API with `native_toolchain_c` so users can call `await xmakeLibrary.build(input: input, output: output)` directly.

---

- **变更**：API 与 native_toolchain_c，采用 await xmakeLibrary.build(input, output) 的形式，简化用户使用

## 0.0.4

- **fix**: find versioned `.dylib` files on macOS.
- **feature**: support cross-compiling from macOS.
- **breaking**: remove automatic xmake installation. Install xmake from the command line:

  ```bash
  dart run native_toolchain_xmake:install
  ```

---

- **修复**：mac 有 lib.xxx.dylib 形式
- **功能**：在 mac 上交叉编译
- **变更**：移除自动安装，通过命令行安装

  ```bash
  dart run native_toolchain_xmake:install
  ```

## 0.0.3

- **feature**: support cross-compilation using Zig.
- **fix**: find versioned `.so` files on Linux.

---

- **功能**：支持交叉编译，采用 zig 来交叉编译
- **修复**：linux 上的动态库可能为 lib.so.xxx 形式，因此需要智能地匹配相应文件

## 0.0.2

- **fix**: check that xmake is available after installation and prompt users to refresh their environment if the `PATH` update has yet to take effect.
- **fix**: pass `-P .` to specify the project directory for nested xmake projects.

---

- **修复**：验证 xmake 的安装。提示用户可能已经安装但是环境变量没有生效
- **修复**：xmake 存在工程嵌套的的问题，采用 xmake -P . 来设置 xmake 的项目


## 0.0.1

- **feature**: install xmake automatically.
- **feature**: support building and integrating dynamic libraries.

---

- **功能**：自动安装 xmake
- **功能**：支持集成动态库
