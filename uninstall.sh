#!/bin/bash

echo "Remove link..."

srcPath=$(dirname `readlink -e "$0"`)
configPath="${srcPath}/config.conf"
binPath=$(grep <"$configPath" "binPath" | awk -F "[ :=]+" '{print $2}')

travereBin(){
    local lkLs=($(find "$binPath"))
    for i in ${lkLs[@]};do
        realPath=$(readlink -e "$i")
        if [[ $realPath == "$srcPath"* ]];then
            hadFound=1
            echo "Remove ${i}"
            rm -f "$i"
        fi
    done
    
}
getBinPath() {
    local IFS=":"
    for dir in $PATH; do
        if [[ "$dir" == "$HOME"* ]]; then
            binPath="$dir"
            travereBin
        fi
    done

}
travereBin

if [ -z $hadFound ];then
    getBinPath
fi
if [ -z $hadFound ];then
    echo "Not Found link."
else
    echo "Sucess."
fi
    
