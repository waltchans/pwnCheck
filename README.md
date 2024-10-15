# pwnCheck

## 简介

集成了CTF竞赛PWN方向用户态题的大部分准备工作。

包括如下内容：

1. 检查ELF文件保护机制
2. 自动确定libc版本
3. 获取基本的ROP gadget
4. 修改ELF的动态链接器
5. 沙盒检测

上述工作大部分命令过于繁琐，因此将其集成在脚本中，实现自动化准备工作。

![image-20241015142817961](./assert/autoCheck)

## 安装

需要已安装`pwntools`，`seccomp-tools`，`patchelf`，`ROPgadget`等pwn工具。

拉取git仓库后运行`install.sh`。

```bash
git clone https://github.com/waltchans/pwnCheck.git
cd pwnCheck
./install.sh
```

在安装过程中，需设置glibc-all-in-one的地址。可**自定义**命令名称，回车表示采取`[ ]`内的默认值。

![image-20241015144039036](./assert/install)

## 使用

### checkAll

check elf all in one. 检查全部选项，包括修改动态链接。默认命令名称为`celf`。

```bash
celf <elf> [lib]
```

- elf: ELF文件路径。
- lib: 可选，libc文件路径。若未指定，则自动搜索当前目录下的全部libc文件。

### autoPatch

auto patch elf. 自动修改ELF的动态链接器。默认命令名称为`pelf`。

```
pelf <elf> [lib]
```

- elf: ELF文件路径。
- lib: 可选，可指定`版本号`、`libc路径`或`libc所在目录`。

#### lib选项

不同选项会遵循如下逻辑：

| lib内容             | 功能                                                         | 示例   |
| ------------------- | ------------------------------------------------------------ | ------ |
| lib路径/lib所在目录 | 判断该lib版本。若存在ld文件，则以该文件/文件夹为patch路径。否则在glibc-all-in-one中查找相同版本的lib。 | `./`   |
| 版本号              | 在glibc-all-in-one中查找名称匹配的可选项。                   | `2.35` |
| 空                  | 列出glibc-all-in-one中全部可选项。                           |        |

指定lib路径，无ld则自动匹配glibc-all-in-one：

![image-20241015153025477](./assert/patchByPath)

指定版本，仅显示匹配项:

![image-20241015150142792](./assert/patchByVersion)

若指定lib选项时无法匹配版本，则会提供全部选项以供选择。

![image-20241015152832577](./assert/patchNoMatch)

##### 覆盖提示

若文件已存在patched版本，则显示已patched文件链接信息，并询问是否覆盖：

![image-20241015153230915](./assert/hadPatch)

