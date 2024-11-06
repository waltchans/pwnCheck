#!/bin/bash

echo "Remove link..."

srcPath=$(dirname `readlink -e "$0"`)
configPath="${srcPath}/config.conf"
binPath=$(grep <"$configPath" "binPath" | awk -F "[ :=]+" '{print $2}')

travereBin(){
    local IFS=$'\n'
    local lkLs=($(find "$binPath"))
    for i in ${lkLs[@]};do
        realPath=$(readlink -f "$i")
        if [[ "$realPath" == "$srcPath"* ]];then
            hadFound=1
            echo "Remove ${i}"
            ${rmCmd} -f "$i"
            if [ $? -ne 0 ]; then
                echo "Delete link Fault."
                exit 1
            fi
        fi
    done
    
}
getBinPath() {
    local IFS=$':'
    for dir in $PATH; do
        if [[ "$dir" == "$HOME"* ]]; then
            binPath="$dir"
            travereBin
        fi
    done

}

if [[ "$binPath" == "/usr/bin" ]];then
    rmCmd="sudo rm"
else
    rmCmd="rm"
fi

if [ -d "$binPath" ]; then
    travereBin
fi

if [ -z $hadFound ];then
    getBinPath
fi

if [ -z $hadFound ];then
    echo "Not Found link."
else
    echo "Sucess."
fi
    
