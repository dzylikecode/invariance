# py embed

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
  ```

> [!NOTE]
>
> ```bash
> conda config --set auto_activate_base false
> ```


## develop


```bash
conda create -n py_embed python=3.8.20 pip

conda activate py_embed
```

> 选取 3.8.20 是因为 mac M 系列只支持部分的 3.8，所以就干脆只有最后一个版本

