## 0.0.5-wip

- 支持 treeshake
- 与 native_toolchain_c 对齐，简化用户使用

## 0.0.4

- find lib.xxx.dylib on mac
- support compile linux target on mac
- 重大改变：移除自动安装 xmake，而是通过命令安装

## 0.0.3

- use zig to cross compile
- find lib.so.xxx on linux

## 0.0.2

- fix: verify xmake after install; if missing, prompt user to restart terminal/system for PATH to take effect.
- fix: nest xmake project, add '-P .' to xmake command to specify the project path.

## 0.0.1

- feature: install xmake automatically
- feature: compile source code to dynamic library
