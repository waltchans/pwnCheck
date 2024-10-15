#!/bin/bash

srcPath=$(dirname `readlink -e "$0"`)
configPath="${srcPath}/config.conf"

getCfg() {
    local config=${2:-$configPath}
    echo $(grep <"$config" "$1" | awk -F "[ :=]+" '{print $2}')
}
inputCfg() {
    local info="$1"
    local oldVal="$2"
    if [ ! -z $oldVal ];then
        info="${info} [ $oldVal ]"
    fi
    read -r -p "$info: " answer
    echo "${answer:-$oldVal}"
}
putCfg() {
    local varName="$1"
    local varVal="$2"
    printf "%s: %s\n" "$1" "$2" >> "$configPath"
}

getBinPath() {
    local IFS=":"
    for dir in $PATH; do
        if [[ "$dir" == "$HOME"* ]]; then
            binPath="$dir"
            break
        fi
    done
}
cmdExist() {
    command -v "$1" >/dev/null 2>&1 
    ret="$?"
    if [ $ret -ne 0 ]; then
        echo "[!] Command \"${1}\" NOT found."
    fi
}

cmdExist "checksec"
cmdExist "ROPgadget"
cmdExist "patchelf"
cmdExist "seccomp-tools"


# Load old config
if [ -f "$configPath" ]; then
    ${srcPath}/uninstall.sh
    cp "$configPath" "${configPath}_bak"
    trap 'echo "Stop while running!"; cp "${configPath}_bak" "$configPath"; rm -f "${configPath}_bak"; exit' INT

    glibcAllPath=$(getCfg "glibcAllPath")
    patchedSuffix=$(getCfg "patchedSuffix")
    patchCmd=$(getCfg "patchCmd")
    checkCmd=$(getCfg "checkCmd")
fi


# Default parameter
glibcAllPath=${glibcAllPath:-"/glibc-all-in-one/libs"}
patchedSuffix=${patchedSuffix:-"_pe"}
patchCmd=${patchCmd:-"pelf"}
checkCmd=${checkCmd:-"celf"}
binPath="$HOME/.local/bin"

# Set config from user
glibcAllPath=$(inputCfg "Set glibc-all-in-one path" "$glibcAllPath")
if [ ! -d "$glibcAllPath" ];then
    echo "[!] glibc-all-in-one Path is illegal."
fi
patchedSuffix=$(inputCfg "Set the SUFFIX of the patched elf" "$patchedSuffix")
checkCmd=$(inputCfg "Set command name of checkAll" "$checkCmd")
patchCmd=$(inputCfg "Set command name of autoPatch" "$patchCmd")

# write conf
echo -e "Writing config...\r"
echo "# config of autoElfCheck" > "$configPath"
putCfg "glibcAllPath" "$glibcAllPath"
putCfg "patchedSuffix" "$patchedSuffix"
putCfg "patchCmd" "$patchCmd"
putCfg "checkCmd" "$checkCmd"

if [ $? -eq 0 ];then
    echo "Write config sucess."
else
    echo "Something Error"
    exit
fi

# Make link
echo "Make link to script..."
if [[ ":$PATH:" != *":$binPath:"* ]]; then
    binPath=
    getBinPath
fi

if [ -z $binPath ];then
    echo "Need sudo to make link in /usr/bin."
    binPath="/usr/bin"
    lnCmd="sudo ln"
else
    lnCmd="ln"
fi
putCfg "binPath" "$binPath"

$lnCmd -s "${srcPath}/src/checkAll.sh" "${binPath}/${checkCmd}"
if [ $? -ne 0 ]; then
    echo "Make link Fault. Exit."
    exit 1
fi
$lnCmd -s "${srcPath}/src/autoPatch.sh" "${binPath}/${patchCmd}"

rm -f "${configPath}_bak"
echo "Finish."
