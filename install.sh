#!/bin/bash

srcPath=$(dirname `readlink -e "$0"`)
configPath="${srcPath}/config.conf"

getCfg() {
    local config=${2:-$configPath}
    echo $(grep <"$config" "$1" | awk -F "[:=]+" '{print $2}')
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
    printf "%s=%s\n" "$1" "$2" >> "$configPath"
}

getBinPath() {
    local IFS=':'
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

createLink() {
    local file="$1"
    local defName="$2"
    while [ 1 ]; do
    
        read -r -p "Set command name of $file. Input # NOT to set [$defName]: " cmd
        if [[ "$cmd" == "#" ]]; then
            return 1
        fi
        

        $lnCmd -s "${srcPath}/src/${file}" "${binPath}/${cmd:-$defName}"
        if [ $? -eq 0 ]; then
            return 0
        else
            echo "[!] Fail to create."
        fi
    done
}
cmdExist "checksec"
cmdExist "ROPgadget"
cmdExist "patchelf"
cmdExist "seccomp-tools"


# Load old config
if [ -f "$configPath" ]; then

   
    cp "$configPath" "${configPath}_bak"
    trap 'echo "Stop while running!"; cp "${configPath}_bak" "$configPath"; rm -f "${configPath}_bak"; exit' INT

    glibcAllPath=$(getCfg "glibcAllPath")
    patchedSuffix=$(getCfg "patchedSuffix")
    # patchCmd=$(getCfg "patchCmd")
    # checkCmd=$(getCfg "checkCmd")
    binPath=$(getCfg "binPath")
    defArg=$(getCfg "defArg")
    
    # if [ -d "$binPath" ]; then
    #     ${srcPath}/uninstall.sh
    # fi
fi


# Default parameter
glibcAllPath=${glibcAllPath:-"/glibc-all-in-one/libs"}
originFmt=${originFmt:-'$_bk'}
patchedFmt=${patchedFmt:-'$'}
# patchCmd=${patchCmd:-"pelf"}
# checkCmd=${checkCmd:-"celf"}
defArg=${defArg:-'-clorps'}

binPath="$HOME/.local/bin"

# Set config from user
while [ 1 ]; do
glibcAllPath=$(inputCfg "Set glibc-all-in-one Path" "$glibcAllPath")
if [ ! -d "$glibcAllPath" ];then
    echo "[!] glibc-all-in-one Path is illegal."
else
    break
fi
done
originFmt=$(inputCfg "Set the Format the of the backup ELF (Use $ instead of ELF )" "$originFmt")
patchedFmt=$(inputCfg "Set the Format the of the patched ELF (Use $ instead of ELF )" "$patchedFmt")
defArg=$(inputCfg "Set the Default Args of the all.sh" "$defArg")

# checkCmd=$(inputCfg "Set command name of checkAll" "$checkCmd")
# patchCmd=$(inputCfg "Set command name of autoPatch" "$patchCmd")

# write conf
echo -e "Writing config...\r"
echo "# config of autoElfCheck" > "$configPath"
putCfg "glibcAllPath" "$glibcAllPath"
putCfg "originFmt" "$originFmt"
putCfg "patchedFmt" "$patchedFmt"
putCfg "defArg" "$defArg"
# putCfg "patchCmd" "$patchCmd"
# putCfg "checkCmd" "$checkCmd"

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
rm -f "${configPath}_bak"
trap 'exit' INT

echo "Finish Write Config."
echo 
read -n1 -p $'Do you want to create Link to the script?\nIf Link is already created, you can skip this step. \nContinuing will delete the OLD link\nYour choice [Y/n]:' answer
case $answer in
    N|n)
        echo 'Quit'	
        exit 0
        ;;
    *)
        echo 'To create.'
        echo 
        ;;
esac
${srcPath}/uninstall.sh
createLink "all.sh" "pca"
createLink "libinfo.sh" "pcl"
createLink "onegadget.sh" "pco"
createLink "ropgadget.sh" "pcr"
createLink "patch.sh" "pcp"





