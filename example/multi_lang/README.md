## Usage

### Run the C++ example

From `example/multi_lang`, run:

```sh
cd backend/cpp
xmake -P .
xmake run -P . main
```

`-P .` selects the C++ project's `xmake.lua`. Without it, Xmake can select the
parent `xmake.lua` used by the Dart hooks. If Xmake reads the C++ project's
cached configuration with that parent script, the package install rule reports
`Package is not attached to target: multi_lang`.

## Additional information

TODO: Tell users more about the package: where to find more information, how to
contribute to the package, how to file issues, what response they can expect
from the package authors, and more.
