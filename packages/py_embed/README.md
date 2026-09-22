# py embed

- 选择了 python 就不要在意速度，而是实现


## quick start

```bash
conda activate rl
dart run g1
```

## env

miniconda:

- windows

  ```bash
  winget install Anaconda.Miniconda3
  # path/to/conda.bat
  conda init powershell
  ```

- mac

  ```bash
  brew install --cask miniconda
  conda init "$(basename "${SHELL}")"
  ```

> [!NOTE]
>
> ```bash
> conda config --set auto_activate false
> ```


## develop


```bash
conda create -n py_embed_3_8_20 python=3.8.20 pip

conda activate py_embed_3_8_20

conda create -n py_embed_3_9_25 python=3.9.25 pip

conda activate py_embed_3_9_25
```

> 选取 3.8.20 是因为 mac M 系列只支持部分的 3.8，所以就干脆只有最后一个版本

## xmake

> [!NOTE]
>
> 这里的 xmake 这是为了用来生成 compile_commands.json 给 IDE 提示用的
> 执行 xmake build 出错无妨

