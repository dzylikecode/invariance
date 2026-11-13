## 0.1.0

- update: native_toolchain_c 修复了中文系统环境下调用 vs 输出非 utf-8 编码问题
- breaking: `LinkModeOption` 改名为 `LinkHookMode`，`linkModeOption` 改为 `linkHook`。`.static`、`.dynamic`、`.byPreference` 分别改为 `.always`、`.never`、`.auto`。
- 新增随包发布的 Agent Skill，覆盖动态库打包、tree-shaking 和常见排错。

---

- 更新: native_toolchain_c: ^0.19.6, 修复了中文环境下 vswhere 输出 utf-8 被解析错误的问题
- 变更：`LinkModeOption` 改名为 `LinkHookMode`，`linkModeOption` 改为 `linkHook`。`.static`、`.dynamic`、`.byPreference` 分别改为 `.always`、`.never`、`.auto`。
- 功能：Agent Skill，覆盖动态库打包、tree-shaking 和常见排错。

## 0.0.10

- fix: link 模式寻找静态库而不是动态库

---

- 修复： link 模式下，需要寻找的是静态库而不是动态库

## 0.0.9

- desktop 交叉编译，不同架构也是交叉编译

---

- 修复：即使是同系统，但是架构不同也是交叉编译

## 0.0.8

- 添加 linkOption 支持用户决定是否启动 tree-shake

---

- 功能：添加 linkOption 字段，让用户决定是否启用 tree-shake

## 0.0.7

- update code_assets to 2.0.0

---

- 更新: code_assets: ^2.0.0

## 0.0.6

- export library.dart

---

- 修复：默认导出 library.dart

## 0.0.5

- 与 native_toolchain_c 对齐，简化用户使用

---

- 变更：API 与 native_toolchain_c，采用 await xmakeLibrary.build(input, output) 的形式，简化用户使用

## 0.0.4

- find lib.xxx.dylib on mac
- support compile linux target on mac
- 重大改变：移除自动安装 xmake，而是通过命令安装

---

- 修复：mac 有 lib.xxx.dylib 形式
- 功能：在 mac 上交叉编译
- 变更：移除自动安装，通过命令行安装

  ```bash
  dart run native_toolchain_xmake:install
  ```

## 0.0.3

- use zig to cross compile
- find lib.so.xxx on linux

---

- 功能：支持交叉编译，采用 zig 来交叉编译
- 修复：linux 上的动态库可能为 lib.so.xxx 形式，因此需要智能地匹配相应文件

## 0.0.2

- fix: verify xmake after install; if missing, prompt user to restart terminal/system for PATH to take effect.
- fix: nest xmake project, add '-P .' to xmake command to specify the project path.

---

- 修复：验证 xmake 的安装。提示用户可能已经安装但是环境变量没有生效
- 修复：xmake 存在工程嵌套的的问题，采用 xmake -P . 来设置 xmake 的项目


## 0.0.1

- feature: install xmake automatically
- feature: compile source code to dynamic library

---

- 功能：自动安装 xmake
- 功能：支持集成动态库
