#!/bin/bash
# libcdir="/glibc-all-in-one/"

# work_location="$(pwd)"
lineChr='-'

srcPath=$(dirname `readlink -e "$0"`)/../
configPath="${srcPath}/config.conf"
patchCmd=$(grep <"$configPath" "patchCmd" | awk -F "[ :=]+" '{print $2}')


# echo $0
# echo $1
# echo $2

if [ $# -gt 2 ]; then
	echo 'Up to 2 parameter!'
	exit
fi

# check elf secure 
if [ $# -ge 1 ]; then
    elfName=$1
else
    elfName="pwn"
fi

drawLine(){
	local ScreenLen=$(stty size |awk '{print $2}')
	local TitleLen=$(echo -n $1 |wc -c)
	local LineLen=$(((${ScreenLen} - ${TitleLen}) / 2 ))
	yes ${lineChr} |sed ''''${LineLen}'''q' |tr -d "\n" && echo -n $1 && yes ${lineChr} |sed ''''${LineLen}'''q' |tr -d "\n" && echo

}
getGadget(){
    local rfile="$1"
    drawLine "Gadgets in $2"
    ROPgadget --binary "./$rfile" --only 'syscall|pop|ret' | grep -v "ret .*" |grep -E "syscall|rdi|rsi|rdx|rcx|r10|r8|r9|: ret"   
    
}

drawLine "ELF Check"
if [ -f ${elfName} ]; then
    printf "[+] ELF Path: %s\n" "$(dirname $elfName)/$(basename $elfName)"
    checksec --file "$elfName" 2>&1
    # elf_info=$(checksec --file $elfName 2>&1 | tee /dev/tty)
    # elf_arch=$(echo "$elf_info" | grep -oP "Arch:     \K[^-]*")
    # printf "arch: %s\n" "$elf_arch"
    
else
    echo "No find the ELF file!"
    exit
fi



# check libc version
if [ ! -z $2 ] && [ -e $2 ]; then
    libc_path_list=(`find "$2" -type f -name "libc-*.so" -o -name "libc.so.6"`)
else
    libc_path_list=(`find . -type f -name "libc-*.so" -o -name "libc.so.6"`)
fi
# libc_path_list=$( ls -l ${work_location} | grep "libc.*")
# libc_path_list=($( find . -type f -name "libc-*.so" -o -name "libc.so.6" ))

drawLine "Libc Check"
echo -ne "\e[37m"
printf "[+] Libc Found: \n"
for i in ${!libc_path_list[@]};do
    libc_path=${libc_path_list[$i]}
    lib_ver=$(strings $libc_path | grep -oP 'Library \(\K[^)]*')
    lib_ver_list[$i]=${lib_ver}
    printf " [%d] %s \t%s\n" "$[i+1]" "$lib_ver" "$libc_path"
done
echo -ne "\e[0m"
# for i in ${!lib_ver_list[@]};do
#     printf "%d:%s\n" $i "${lib_ver_list[$i]}"
# done

# function getlib(){
#     local slibv=("$@")
#     plibc=()
#     for i in ${!slibv[@]};do

#         local obj=${slibv[$i]##* }
#         echo "${libcdir}/${obj}_${arch}"
#         if [ -d ${libcdir}/${obj}_${arch} ];then
#             plibc[${#plibc_path_list[@]}]=${obj}_${arch}
#         fi
#     done
# }

# echo "start"
# getlib "${lib_ver_list[@]}"
# echo "end"
# for i in ${!plibc[@]};do
#     printf "%d:%s\n" $i "${plibc[$i]}"
# done

if [ ${#libc_path_list[@]} -gt 0 ]; then
    printf "Find \33[31m%d\33[0m Libc in current path.\n" ${#libc_path_list[@]}
    if [ ${#libc_path_list[@]} -gt 1 ]; then
        # echo "Choose a libc to use:"
        # select libc_path in ${libc_path_list[@]}
        read -t 5 -p "Switch the libc_path: [1-${#libc_path_list[@]}]" answer
        if [ -z $answer ]; then
            echo "\nTimeout! [1] was selected."
            answer=1
        else
            echo "[${answer}] was selected."
            
        fi
        if [ $answer -gt ${#libc_path_list[@]} ] || [ $answer -le 0] ; then
            echo " [+] Out of range!"
            exit 1
        else
            answer=$[answer-1]
            libc_path=${libc_path_list[$answer]}
            lib_ver=${lib_ver_list[$answer]}
        fi
    else
        libc_path=${libc_path_list[0]}
        lib_ver=${lib_ver_list[0]}
    fi
    
else
    echo "Libc not found."    
fi

printf "\n[+] Libc Info:\n  Version:\t\33[92m%s\33[0m\n  Libc Path:\t%s\n\n" "${lib_ver}" "${libc_path}"

# get gadget which most commonly used 
getGadget "$elfName" "ELF"
getGadget "$libc_path" "${libc_path##*/}"
drawLine "End of gadgets"

# patch libc
drawLine "Patch ELF"
read -t 5 -n1 -p "Patch libc to the elf? [Y/n]" answer
case $answer in
    N|n)
        echo "Don't patch."
        ;;
    *)
        echo "To Patch."
        # lib=${libc_path##* }
        # if [ -d ${libcdir}/${lib}_${arch} ];then
        if [ -n "$libc_path" ]; then
            # echo "with fiel"
            "${patchCmd}" "$elfName" "$libc_path"
        else
            # echo "no libc"
            "${patchCmd}" "$elfName"
        fi
        ;;
        # getlib "${lib_ver_list[@]}"
        # if [ ${#plibc_path_list[@]} -ge 1 ]; then
        #     echo "Choose a libc:"
        #     select obj in ${plibc_path_list[@]} "others"; do
        #         if [ "$obj" != "others" ]; then
                    
        #             "${patchCmd}" "$elfName" "$obj"
        #             break
        #         else
        #             "${patchCmd}" "$elfName"
        #             break
        #         fi
        #     done
        # else
        #     "${patchCmd}" "$elfName"
        # fi
        # ;;
esac
echo 


# getGadget "$elfName"
# echo "${libc_path_list[0]}"
# getGadget "${libc_path_list[0]}"


# check seccomp
drawLine "Check Sandox"
read -t 5 -n1 -p "Check sandbox? [Y/n]" answer
case $answer in
    N|n)
        echo "Don't check sandbox."
        ;;
    *)
        echo "To check sandbox."
        seccomp-tools dump "./$elfName"
        ;;
esac
echo "end"

