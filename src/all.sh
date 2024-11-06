#!/bin/bash

srcPath=$(dirname `readlink -e "$0"`)
configPath="${srcPath}/../config.conf"
# patchCmd=$(grep <"$configPath" "patchCmd" | awk -F "[:=]+" '{print $2}')
defArg=$(grep <"$configPath" "defArg" | awk -F "[:=]+" '{print $2}')

# run info cmd arges
usage() {
    echo -e "$docs"
    exit 1
}

run(){
    info=$1
    shift 
    shellcmd=("$@")

    ${shellcmd[@]} | while IFS= read -r line; do
        echo -e "[$info] $line"
    done
}

drawLine(){
    local lineChr='-'
	local ScreenLen=$(stty size | awk '{print $2}')
	local TitleLen=$(echo -n $1 | wc -c)
	local LineLen=$(((${ScreenLen} - ${TitleLen}) / 2 ))
	yes ${lineChr} |sed ''''${LineLen}'''q' | tr -d "\n" && echo -n $1 && yes ${lineChr} |sed ''''${LineLen}'''q' | tr -d "\n" && echo

}
# quest() {
#     # quest info default time
#     read -t 5 -n1 -p "Patch libc to the elf? [Y/n]" answer
#     return 1
# }

paras=$(getopt -o haclorps -l help,all,sec,lib,one,rop,patch,seccomp -n $(basename $0) -- "$@")
set -- $paras
# echo "$@"
ifSet=0
while [ $1 ];
do
    case $1 in
    -h | --help)
        usage
        shift
        ;;
    -a | --all)
        shift
        set -- -c -l -o -r -p -s "$@"
        needAsk=1
        ;;
    -c | --sec)
        ifSet=1
        todo_sec=1
        shift
        ;;
    -l | --lib)
        ifSet=1
        todo_lib=1
        shift
        ;;
    -o | --one)
        ifSet=1
        todo_lib=1
        todo_one=1
        shift
        ;;
    -r | --rop)
        ifSet=1
        todo_rop=1
        shift
        ;;
    -p | --patch)
        ifSet=1
        todo_patch=1
        shift
        ;;
    -s | --seccomp)
        ifSet=1
        todo_seccomp=1
        shift
        ;;
    --)
        shift
        if [ $ifSet -eq 0 ]; then
            set -- $(getopt -o haclorps -- "$defArg" ) "$@"
            if [ $1 = "--" ]; then
                echo "Default Args Error. Please reset Default args or run with args."
                exit -1
            fi
            needAsk=1
        else
            break
        fi
    esac
done



if [ $# -ge 2 ]; then
    eval libName=$2
fi
if [ $# -eq 0 ]; then
    elfName="pwn"
else
    eval elfName=$1
fi


if [ ! -z $todo_sec ]; then
    drawLine "ELF Check"
    if [ -f ${elfName} ]; then
        printf "[+] ELF Path: %s\n" "$(dirname $elfName)/$(basename $elfName)"
        checksec --file "$elfName" 2>&1
    else
        echo "No find the ELF file!"
        exit 1
    fi
fi

if [ ! -z $todo_lib ]; then
    source "${srcPath}/libinfo.sh" -c "$libName"
fi

if [ ! -z $todo_one ] && [ ! -z $todo_lib ]; then
    drawLine "One Gadget"
    echo -e "\e[92mONEgadget\e[0m | ${libc_path}" 
    "${srcPath}/onegadget.sh" -a "$libc_path"
fi

if [ ! -z $todo_rop ]; then
    drawLine "ROP gadgets"
    run "\e[91mROP ELF\e[0m" "${srcPath}/ropgadget.sh" "$elfName"
    if [ ! -z $todo_lib ];then
        drawLine
        run "\e[95mROP Lib\e[0m" "${srcPath}/ropgadget.sh" "$libc_path"
    fi
    # drawLine "End of ROP gadgets"
fi

if [ ! -z $todo_patch ]; then
    drawLine "Patch ELF"
    if [ ! -z $needAsk ]; then
        read -t 5 -n1 -p "Patch libc to the elf? [Y/n]" answer
    else
        answer=Y
    fi
    case $answer in
        N|n)
            echo "Don't patch."
            ;;
        *)
            echo "To Patch."
            if [ -n "$libc_path" ]; then
                run "\e[94mPatch\e[0m" "${srcPath}/patch.sh" "$elfName" "$libc_path"
            else
                run "\e[94mPatch\e[0m" "${srcPath}/patch.sh" "$elfName"
            fi
            ;;
    esac
    echo 
fi
if [ ! -z $todo_seccomp ]; then
    drawLine "Check Sandox"
    if [ ! -z $needAsk ]; then
        read -t 5 -n1 -p "Check sandbox? [Y/n]" answer
    else
        answer=Y
    fi
    case $answer in
        N|n)
            echo "Don't check sandbox."
            ;;
        *)
            echo "To check sandbox."
            # run "\e[36mseccomp\e[0m" "${srcPath}/seccomp.sh" "$elfName"
            seccomp-tools dump "$(dirname $elfName)/$(basename $elfName)" 2>/dev/null
            ;;
    esac
fi


drawLine
echo "[+] Check End."

