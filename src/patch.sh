#!/bin/bash

srcPath=$(dirname `readlink -ne "$0"`)
configPath="${srcPath}/../config.conf"
aioDir=$(grep <"$configPath" "glibcAllPath" | awk -F "[:=]+" '{print $2}')
originFmt=$(grep <"$configPath" "originFmt" | awk -F "[:=]+" '{print $2}')
patchedFmt=$(grep <"$configPath" "patchedFmt" | awk -F "[:=]+" '{print $2}')


originFmt=${originFmt:-'$_bk'}
patchedFmt=${patchedFmt:-'$'}

# help
docs="Patchelf with glibc-all-in-one. 
Usage:\t$0 elf [lib|path|ver]
Options:
\t-h, --help\tPrint Display this help and exit
\t-o, --output\tSpecify output file
Args:
\tELF\tWitch to be patch. Optionally enter the ORIGIN name or ORIGINFMT name
\tlib\tWitch LIB to link. If not find LD in the same path, will choose the same version in glibc-all-in-one
\tpath\tPath to a LIB 
\tver\tMatch the version in glibc-all-in-one

Example:
\t$0 pwn libc.so.6
\t$0 pwn libc/
\t$0 pwn 2.35
"
usage() {
    echo -e "$docs"
    exit 1
}

drawLine(){
	local lineChr='-'
	local ScreenLen=$(stty size |awk '{print $2}')
	local TitleLen=$(echo -n $1 |wc -c)
	local LineLen=$(((${ScreenLen} - ${TitleLen}) / 2 - 10 ))
	yes ${lineChr} |sed ''''${LineLen}'''q' |tr -d "\n" && echo -n $1 && yes ${lineChr} |sed ''''${LineLen}'''q' |tr -d "\n" && echo

}

paras=$(getopt -o ho: -l help,output: -n $(basename $0) -- "$@")
set -- $paras
# echo "$@"
while [ $1 ];
do
    case $1 in
    -o | --output)
		eval patchedFile=$2
        shift 2
        ;;
    -h | --help)
        usage
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
eval elfFile=$1

elfPath=$( dirname "$elfFile" )
elfBase=$( basename "$elfFile" )

if [[ "$originFmt" =~ '$' ]]; then
	shiftFmt=${originFmt//$/'\(.*\)'}
	shiftName=$( expr match "$elfBase" "^${shiftFmt}\$" )
	if [ $? -eq 0 ]; then
		elfBase="${shiftName}"
	fi
fi



# Check elf legal

originFile="$elfPath/${originFmt//$/$elfBase}"
if [ -z $patchedFile ]; then
	patchedFile="$elfPath/${patchedFmt//$/$elfBase}"
fi

if [ ! -f "$elfFile" ] && [ ! -f "$originFile" ]; then
	echo -e "\e[31m[!] ELF file is illegal.\e[0m"
	exit 1
fi

# backup the origin ELF file
if [ ! -f "${originFile}" ] && [ -f "${elfFile}" ]; then
	mv "${elfFile}" "${originFile}"
fi
printf "[+] Patch ELF: %s\n" "$elfPath/$elfBase"


# check whether the patched elf existed.

if [ -f "${patchedFile}" ]; then
	if [ "$patchedFile" = "$originFile" ]; then
		echo -e '[!] The ORIGIN ELF will be \e[31mMODIFIED\e[0m.\n    You might be UNABLE to run it.'
	else
		echo -e '[!] The ELF has been \e[31mPATCHED\e[0m a LIB.'
	fi
	drawLine "Link Info"
	echo -ne "\e[37m"
	ldd "${patchedFile}"
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
	local elfArch=$(checksec --file "$originFile" 2>&1 | grep -oP "Arch:     \K[^-]*")
	local libVersion=$(strings "$libcFile" | grep -oP 'Library \(\K[^)]*')
	local libVer=${libVersion##* }
	# echo $elfArch 
	# echo $libVer
	if [ -z "$elfArch" ] || [ -z "$libVer" ]; then
		echo -e "\e[31m[!] Error: Fault in extract libc infomation.\e[0m"
		exit 1
	fi
	libInfo="${libVer}_${elfArch}"
}

# check lib path then load
checkLib() {
	local path="$1"
	# echo "$path"

	if [ ! -d "$path" ]; then
		return 3
	fi
	IFS=$'\n'
	local libcList=(`find "$path" -type f -name "libc-*.so" -o -name "libc.so.6"`)
	if [ ${#libcList[@]} -eq 0 ]; then
		return 2
	fi
	libcPath="${libcList[0]}"
	# echo "$path"
	local ldList=(`find "$path" -type f -name "ld-*.so" -o -name "ld-linux*.so.2"`)
	# echo "${#ldList[@]}"
	unset IFS
	if [ ${#ldList[@]} -eq 0 ]; then
		return 1
	fi
	ldPath="${ldList[0]}"
	libPath="$path"
	return 0
}


aioDir=${aioDir%/}
if [ $# -ge 2 ]; then
	eval argLib="$2"
	if [ -e "$argLib" ]; then
		if [ -f "$argLib" ]; then
			extractLib "$argLib"
			checkLib "$( dirname "${argLib}" )"
			clRes="$?"
			libcPath="$argLib"
		else
			argLib=${argLib%/}
			checkLib "$argLib"
			clRes="$?"
			extractLib "${libcPath}"
		fi

		if [ $clRes -lt 2 ]; then 
			printf "[+] Libc Info: \33[93m%s\33[0m -- %s\n" "${libInfo}" "$(dirname $libcPath)/$(basename $libcPath)"
			if [ $clRes -gt 0 ]; then
				echo -e "\e[31m[!]\e[0m No match ld. So match in the LIBs. "
				checkLib "${aioDir}/${libInfo}"
				if [ $? -gt 0 ]; then 
					echo -e "\e[31m[!]\e[0m There is no match in the LIBs. "
				fi
			fi
		else
			echo -e "\e[31m[!]\e[0m The LIB Path is error. "
		fi
	else
		libFilt="${argLib}"
	fi
fi

if [ -z $libPath ]; then
	# aioList=$( ls -l "${aioDir}/" | grep '^d' | cut -c 44- )
	aioList=$( find "${aioDir}/" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; )
	if [ ! -z "$libFilt" ]; then
		filtRes=$( echo "$aioList" | grep "$libFilt" )
		if [ ${#filtRes[@]} -gt 0 ]; then
			aioList="${filtRes[@]}"
		else
			echo "\e[31m[!]\e[0m Lib version can not match."
		fi
	fi
	echo -e "\e[34m[?]\e[0m Choose a LIB to PATCH:"
	select obj in  "NO Patch" ${aioList[@]}; do
		if [ "$obj" != "NO Patch" ]; then
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
	if [ ! "$patchedFile" = "$originFile" ]; then
		if [ -f "${patchedFile}" ]; then
			diff "${originFile}" "${patchedFile}" > /dev/null
			if [ $? -eq 1 ]; then
				rm -f "${patchedFile}"
			fi
		fi
		cp "${originFile}" "${patchedFile}"
	fi
	# echo $libPath
	# echo $patchedFile
	# echo $ldPath
	patchelf --set-interpreter "${ldPath}" "${patchedFile}"
	ldRes=$?
	patchelf --replace-needed libc.so.6 "${libcPath}" ${patchedFile}
	patchelf --set-rpath "${libPath}" "${patchedFile}"
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

