#!/bin/bash

docs="Search the Libc File and dump the version info.
Usage:\t$0 [ELF|path]
Default to Search current path.

Example:
\t$0
\t$0 .
\t$0 ./libc.so.6
\t$0 /lib
"

usage() {
    echo -e "$docs"
    exit 1
}
paras=$(getopt -o hc -l help -n $(basename $0) -- "$@")
set -- $paras

# echo "$@"
while [ $1 ];
do
    case $1 in
    -h | --help)
        shift
        usage
        ;;
    -c)
        shift
        verbose=y
        ;;
    --)
        shift
        break
        ;;
    esac
done

# check libc version
IFS=$'\n'
eval searchPath=$1

if [ $# -ge 1 ] && [ -e "$searchPath" ]; then
    if [ -d $searchPath ] && [ -L $searchPath ];then
        searchPath="${searchPath}/"
    fi
    libc_path_list=(`find "$searchPath" -type f -name "libc-*.so" -o -name "libc.so.6"`)
    # echo "${libc_path_list[@]}"
else
    libc_path_list=(`find . -type f -name "libc-*.so" -o -name "libc.so.6"`)
fi
unset IFS

# drawLine "Libc Check"
echo -ne "\e[37m"
printf "[+] Libc Found: \n"
for i in ${!libc_path_list[@]};do
    libc_path="${libc_path_list[$i]}"
    lib_ver=$(strings "$libc_path" | grep -oP 'Library \(\K[^)]*')
    lib_ver_list[$i]="${lib_ver}"
    printf " [%d] %s \t%s\n" "$[i+1]" "$lib_ver" "$libc_path"
done
echo -ne "\e[0m"


if [ ${#libc_path_list[@]} -gt 0 ]; then
    printf "Find \33[31m%d\33[0m Libc in current path.\n" "${#libc_path_list[@]}"
else
    echo "Libc not found."    
fi

if [[ $verbose != "y" ]]; then
    exit 0
fi


if [ ${#libc_path_list[@]} -gt 1 ]; then
    read -t 20 -p "Switch the libc_path: [1-${#libc_path_list[@]}]" answer
    if [ -z $answer ]; then
        echo "\nTimeout! [1] was selected."
        answer=1
    else
        echo "[${answer}] was selected."
        
    fi
    if [ $answer -gt ${#libc_path_list[@]} ] || [ $answer -le 0 ] ; then
        echo " [+] Out of range!"
        exit 1
    else
        answer=$((answer-1))
        libc_path="${libc_path_list[$answer]}"
        lib_ver="${lib_ver_list[$answer]}"
    fi
else
    libc_path="${libc_path_list[0]}"
    lib_ver="${lib_ver_list[0]}"
fi

printf "\n[+] Libc Info:\n  Version:\t\33[92m%s\33[0m\n  Libc Path:\t%s\n\n" "${lib_ver}" "${libc_path}"
