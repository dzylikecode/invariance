# xmake

dart is the first-class citizen in the project.

## cross-compile

```bash
dart build cli --target example/call.dart --target-os linux --target-arch x64
```

## notes

### add_headerfiles and add_includedirs

```lua
add_includedirs("include", {public = true})
```

有两个作用:

首先，编译 `foo` 自己时会有：

```bash
-I/path/to/foo/include
```

其次，因为有：

```lua
{public = true}
```

如果另一个 target：

```lua
target("app")
    add_deps("foo")
```

那么 `app` 也会自动获得这个 include path。

所以它可以直接：

```cpp
#include <foo/foo.h>
```

---

而：

```lua
add_headerfiles("include/(foo/*.h)")
```

这里的括号还有一个重要作用。

源目录：

```text
include/foo/foo.h
include/foo/types.h
```

安装之后会变成：

```text
include/
└── foo/
    ├── foo.h
    └── types.h
```

而不是：

```text
include/
└── include/
    └── foo/
        ├── foo.h
        └── types.h
```

也就是说：

```lua
add_headerfiles("include/(foo/*.h)")
```

括号表示安装时从括号里面这一层开始保留目录结构。

## 如何处理不同的结构体

