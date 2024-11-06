#!/bin/bash

# help
docs="Search One Gadget and dump with python code. 
Usage:\t$0 elf [OPTION] ELF
Options:
\t-h, --help\tPrint Display this help and exit
\t-p, --pydump\tConvert the Output to a Python list {DEFAULT}
\t-o, --origin\tEcho the original Output
\t-a, --all\tBoth of pydump and origin

Example:
\t$0 libc.so.6
\t$0 -p libc.so.6
\t$0 -a libc.so.6
"
usage() {
    echo -e "$docs"
    exit 2
}

paras=$(getopt -o hapo -l help,all,pydump,origin -n $(basename $0) -- "$@")
set -- $paras
todoType=2
while [ $1 ]; do
    case $1 in
    -h | --help)
        usage
        shift
        ;;
    -a | --all)
        todoType=3
        shift
        ;;
    -p | --pydump)
        todoType=2
        shift
        ;;
    -o | --origin)
        todoType=1
        shift
        ;;
    --)
        shift
        break
        ;;
    esac
done

if [ $# -eq 0 ]; then
    usage
fi

eval elfName="$1"
if [ ! -f "$elfName" ]; then
	echo -e "\e[31m[!] ELF file is illegal.\e[0m"
	exit 1
else
	elfName="$(dirname $elfName)/$(basename $elfName)"
fi


if [ $todoType -eq 1 ]; then
    one_gadget "$elfName"
    exit
fi


totalInfo=$( one_gadget "$elfName" )
IFS=$'\n'
addrInfo=( $( echo "$totalInfo" | grep "execve" ) )
unset IFS

if [ $todoType -eq 3 ]; then

    echo "$totalInfo"
fi

if [ $todoType -ge 2 ]; then
    echo "oneGadgets = ["

    for idx in ${!addrInfo[@]};do
        item=${addrInfo[$idx]}
        hexstr=($(echo "$item" | grep -oP "\b0x[0-9A-Fa-f]+\b" ))
        address=${hexstr[0]}
        info=${item##*$address}	
        
        printf "    %s, # [%d]:%s \n" "$address" "$idx" "$info"
    done

    echo "] # python List of one_gadget"
fi