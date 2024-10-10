#!/bin/bash
libcdir="/glibc-all-in-one/"

work_location="$(pwd)"
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
echo $elfName
if [ -f ${elfName} ]; then
    printf "ELF Check : \"%s\"\n" "$elfName"
    info=$(checksec --file $elfName 2>&1 | tee /dev/tty)
    arch=$(echo "$info" | grep -oP "Arch:     \K[^-]*")
    printf "arch: %s\n" "$arch"
    
else
    echo "No find the ELF file!"
    exit
fi


# check libc version
libList=(`find . -type f -name "libc-*.so" -o -name "libc.so.6"`)
# libList=$( ls -l ${work_location} | grep "libc.*")
# libList=($( find . -type f -name "libc-*.so" -o -name "libc.so.6" ))

for i in ${!libList[@]};do
    lb=${libList[$i]}
    lbv=$(strings $lb | grep -oP 'Library \(\K[^)]*')
    libver[$i]=${lbv}
    
    printf " [%d] %s \t%s\n" $i "$lbv" "$lb"
done

# for i in ${!libver[@]};do
#     printf "%d:%s\n" $i "${libver[$i]}"
# done

function getlib(){
    local slibv=("$@")
    plibc=()
    for i in ${!slibv[@]};do

        local obj=${slibv[$i]##* }
        echo "${libcdir}/${obj}_${arch}"
        if [ -d ${libcdir}/${obj}_${arch} ];then
            plibc[${#plibList[@]}]=${obj}_${arch}
        fi
    done
}

# echo "start"
# getlib "${libver[@]}"
# echo "end"
# for i in ${!plibc[@]};do
#     printf "%d:%s\n" $i "${plibc[$i]}"
# done

if [ ${#libList[@]} -gt 0 ]; then
    printf "Find \33[31m%d\33[0m Libc in current path.\n" ${#libList[@]}
    if [ ${#plibList[@]} -ge 1 ]; then
        echo "Choose a libc to use:"
        select lib in ${libList[@]}
    else
        lib=${libList[0]}
    fi
else
    echo "Libc not found."    
fi


# patch libc
    
read -t 5 -n1 -p "Patch libc to the elf? [Y/n]" answer
case $answer in
    N|n)
        echo "Don't patch."
        ;;
    *)
        echo "To Patch."
        if [ -d ${libcdir}/${obj}_${arch} ];then
            pelf "$elfName" "$obj"
        else
            pelf "$elfName"
        fi
        ;;
        # getlib "${libver[@]}"
        # if [ ${#plibList[@]} -ge 1 ]; then
        #     echo "Choose a libc:"
        #     select obj in ${plibList[@]} "others"; do
        #         if [ "$obj" != "others" ]; then
                    
        #             pelf "$elfName" "$obj"
        #             break
        #         else
        #             pelf "$elfName"
        #             break
        #         fi
        #     done
        # else
        #     pelf "$elfName"
        # fi
        # ;;
esac


function getGadget(){
    local cfile="$1"
    ROPgadget --binary "./$cfile" --only 'syscall|pop|ret' | grep -v "ret .*" |grep -E "syscall|rdi|rsi|rdx|rcx|r10|r8|r9|: ret"
    
}

getGadget "$elfName"
echo "${libList[0]}"
getGadget "${libList[0]}"
# check seccomp
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

