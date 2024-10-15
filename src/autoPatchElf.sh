#!/bin/bash

srcPath=$(dirname `readlink -e "$0"`)/../
configPath="${srcPath}/config.conf"
aioDir=$(grep <"$configPath" "glibcAllPath" | awk -F "[ :=]+" '{print $2}')


lineChr='-'

# help
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	cmd=$(basename "$0")
	echo 'Patchelf with glibc-all-in-one. '
	echo -e "Usage:\t${cmd} elf [lib|path|ver]"
	echo 'Example:'
	echo -e "\t${cmd} pwn libc.so.6"
	echo -e "\t${cmd} pwn libc/"
	echo -e "\t${cmd} pwn 2.35"
	exit 1
fi

drawLine(){
	local ScreenLen=$(stty size |awk '{print $2}')
	local TitleLen=$(echo -n $1 |wc -c)
	local LineLen=$(((${ScreenLen} - ${TitleLen}) / 2 ))
	yes ${lineChr} |sed ''''${LineLen}'''q' |tr -d "\n" && echo -n $1 && yes ${lineChr} |sed ''''${LineLen}'''q' |tr -d "\n" && echo

}
# Check elf legal
elfName="$1"
if [ ! -f "$elfName" ]; then
	echo -e "\33[31m[!] ELF file is illegal.\33[0m"
	exit 1
fi
printf "[+] Patch ELF: %s\n" "$(dirname $elfName)/$(basename $elfName)"
# check whether the patched elf existed.
fname="${elfName}_pe"
if [ -f ${fname} ]; then
	echo -e '[!] The file has been \e[31mPATCHED\e[0m a LIB.'
	drawLine "Patched Info"
	echo -ne "\e[37m"
	ldd "${fname}"
	echo -ne "\e[0m"
	drawLine
	printf "\33[34m[?]\33[0m "
	if ! read -t 5 -n1 -p "Do you want to overwriting? [Y/n]" answer; then
		echo ' Timeout'
		answer='Y'
	fi
	case $answer in
		N|n)
			echo '[+] Quit'	
			exit 2
			;;
		*)
			echo '[-] Will be overwritten. '
			echo 
			;;
	esac
fi

# get lib version from libc.so.6
extractLib() {
	local libcFile="$1"
	local elfArch=$(checksec --file $elfName 2>&1 | grep -oP "Arch:     \K[^-]*")
	local libVersion=$(strings "$libcFile" | grep -oP 'Library \(\K[^)]*')
	local libVer=${libVersion##* }
	if [ -z "$elfArch" ] || [ -z "$libVer" ]; then
		echo -e "\33[31m[!] Error: Fault in extract libc infomation.\33[0m"
		exit 1
	fi
	libInfo="${libVer}_${elfArch}"
}

# check lib path then load
checkLib() {
	local path="$1"
	if [ ! -d "$path" ]; then
		return 1
	fi
	local ldList=(`find "$path" -type f -name "ld-*.so" -o -name "ld-linux*.so.2"`)
	if [ ${#ldList[@]} -eq 0 ]; then
		return 2
	fi
	local libcList=(`find "$path" -type f -name "libc-*.so" -o -name "libc.so.6"`)
	if [ ${#libcList[@]} -eq 0 ]; then
		return 3
	fi
	libPath="$path"
	ldPath="${ldList[0]}"
	libcPath="${libcList[0]}"
	return 0
}


aioDir=${aioDir%/}
if [ ! -z $2 ]; then
	argLib="$2"
	if [ -f "$argLib" ]; then
		extractLib "$argLib"
		printf "[+] Libc Info: \33[93m%s\33[0m -- %s\n" "${libInfo}" "$(dirname $argLib)/$(basename $argLib)"
		checkLib "$(dirname '${argLib}')"
		if [ $? -gt 0 ]; then
			echo -e "\e[31m[!]\e[0m No match ld. So match in the LIBs. "
			checkLib "${aioDir}/${libInfo}"
			if [ $? -gt 0 ]; then 
				echo -e "\e[31m[!]\e[0m There is no match in the LIBs. "
			fi
		fi
	elif [ -d "$argLib" ]; then
		checkLib "$argLib"
		if [ $? -gt 0 ]; then 
			echo -e "\e[31m[!]\e[0m The LIB Path is error. "
		fi
		extractLib "${libcPath}"
	else
		libFilt="${argLib}"
	fi
fi

if [ -z $libPath ]; then
	aioList=$( ls -l "${aioDir}/" | grep '^d' | cut -c 44- )
	if [ ! -z "$libFilt" ]; then
		filtRes=$( echo "$aioList" | grep "$libFilt" )
		if [ ${#filtRes[@]} -gt 0 ]; then
			aioList="${filtRes[@]}"
		else
			echo "\e[31m[!]\e[0m Lib version can not match."
		fi
	fi
	echo -e "\e[34m[?]\e[0m Choose a LIB to PATCH:"
	select obj in ${aioList[@]} "Quit"; do
		if [ "$obj" != "Quit" ]; then
			# echo "Patch elf"
			# echo "$1: ${obj}"
			
			# libc=${aioDir}${obj}
			# ld=($(ls -d ${libc}/* | grep "ld-.*\.so"))

			# if [ ${#ld} = 0 ]; then
			# 	echo 'error'
			# 	exit
			# fi
			libInfo="${obj}"
			path="${aioDir}/${obj}"
			checkLib "$path"
			break
		else
			echo "[+] Quit."
			exit 2
		fi
	done
fi

# patch process
if [ -n "$libPath" ] && [ -n "$libcPath" ] && [ -n "$ldPath" ]; then
	echo "Patching..."
	if [ -f ${fname} ]; then
		rm -f "${fname}"
	fi
	cp "$1" "${fname}"
	patchelf --set-interpreter "${ldPath}" ${fname}
	ldRes=$?
	#patchelf --replace-needed libc.so.6 "${libc}/libc.so.6" ${fname}
	patchelf --set-rpath "${libPath}" ${fname}
	rpRes=$?
	if [ $ldRes -eq 0 ] && [ $rpRes -eq 0 ]; then
		echo '[+] Done!'
		printf "Last Patch:\t\33[92m%s\33[0m \nLib Path:\t%s\n" "${libInfo}" "${libPath}/"
		exit 0
	else
		echo 'Error: Fault in patch'
		exit 1
	fi
else
	echo "Error: No such File."
	exit 1
fi

