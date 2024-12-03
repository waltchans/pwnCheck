#!/bin/bash

srcPath=$(dirname `readlink -ne "$0"`)
configPath="${srcPath}/../config.conf"
gaio_dir=$(grep <"$configPath" "glibcAllPath" | awk -F "[:=]+" '{print $2}')
backup_format=$(grep <"$configPath" "originFmt" | awk -F "[:=]+" '{print $2}')
patch_format=$(grep <"$configPath" "patchedFmt" | awk -F "[:=]+" '{print $2}')


backup_format=${backup_format:-'$_bk'}
patch_format=${patch_format:-'$'}

# Get the calling method
cmd=$( basename "$0" )
command -v "$cmd" >/dev/null 2>&1
if [ $? -ne 0 ]; then
	cmd=$0
fi

# help
docs="Patchelf with glibc-all-in-one. 
Usage:\t$cmd elf [lib|path|ver]
Options:
\t-h, --help\tPrint Display this help and exit
\t-o, --output\tSpecify output file
Args:
\tELF\tWitch to be patch. Optionally enter the ORIGIN name or ORIGINFMT name
\tlib\tWitch LIB to link. If not find LD in the same path, will choose the same version in glibc-all-in-one
\tpath\tPath to a LIB 
\tver\tMatch the version in glibc-all-in-one

Example:
\t$cmd pwn libc.so.6
\t$cmd pwn libc/
\t$cmd pwn 2.35
"
usage() {
    echo -e "$docs"
    exit 1
}

draw_line(){
	local line_chr='-'
	local width_len=$( stty size | awk '{print $2}' )
	local title_len=$( echo -n $1 | wc -c )
	local half_len=$(((${width_len} - ${title_len}) / 2 - 10 ))
	local half_str=$( yes "$line_chr" | head -n "$half_len" | tr -d '\n' )
	echo "$half_str$1$half_str"
}

restore_origin_file_exit() {
	backup_file_name=$(basename "$backup_file_path")
	printf "[~] Restore file: %s->%s\n" "${backup_file_name}" "${input_file_name}"
	mv "${backup_file_path}" "${input_file_path}"
	exit 2
}

paras=$(getopt -o ho: -l help,output: -n $(basename $0) -- "$@")
set -- $paras
# echo "$@"
while [ $1 ];
do
    case $1 in
    -o | --output)
		eval patch_file_path=$2
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

# get input file
eval input_file_path=$1
ininput_file_path=$(dirname "$input_file_path")/$(basename "$input_file_path")

input_file_dir=$( dirname "$input_file_path" )
input_file_name=$( basename "$input_file_path" )

# If input is origin_fmt file, transfer to old name 
if [[ "$backup_format" =~ '$' ]]; then
	shift_format=${backup_format//$/'\(.*\)'}
	shift_name=$( expr match "$input_file_name" "^${shift_format}\$" )
	if [ $? -eq 0 ]; then
		input_file_name="${shift_name}"
	fi
fi

# get the patch file name
backup_file_path="$input_file_dir/${backup_format//$/$input_file_name}"
if [ -z $patch_file_path ]; then
	patch_file_path="$input_file_dir/${patch_format//$/$input_file_name}"
fi

# CHeck if elf exist
if [ ! -f "$input_file_path" ] && [ ! -f "$backup_file_path" ]; then
	echo -e "\e[31m[!] ELF file is illegal.\e[0m"
	exit 1
fi

# backup the origin ELF file
if [ ! -f "${backup_file_path}" ] && [ -f "${input_file_path}" ]; then
	first_try_backup=1
	trap "restore_origin_file_exit" SIGINT
	backup_file_name=$(basename "$backup_file_path")
	printf "[~] Backup file: %s->%s\n" "${input_file_name}" "${backup_file_name}"
	mv "${input_file_path}" "${backup_file_path}"
fi
printf "[+] Patch ELF: %s\n" "$input_file_dir/$input_file_name"


# check whether the patched elf existed.

if [ -f "${patch_file_path}" ]; then
	if [ "$patch_file_path" = "$backup_file_path" ]; then
		echo -e '[!] The ORIGIN ELF will be \e[31mMODIFIED\e[0m.\n    You might be UNABLE to run it.'
	else
		echo -e '[!] The ELF has been \e[31mPATCHED\e[0m a LIB.'
	fi
	draw_line "Link Info"
	echo -ne "\e[37m"
	ldd "${patch_file_path}"
	echo -ne "\e[0m"
	draw_line
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
extract_lib() {
	local lib_libc_file="$1"
	local elf_arch=$(checksec --file "$backup_file_path" 2>&1 | grep -oP "Arch:     \K[^-]*")
	local lib_versionsion=$(strings "$lib_libc_file" | grep -oP 'Library \(\K[^)]*')
	local lib_version=${lib_versionsion##* }
	# echo $elf_arch 
	# echo $lib_version
	if [ -z "$elf_arch" ] || [ -z "$lib_version" ]; then
		echo -e "\e[31m[!] Error: Fault in extract libc infomation.\e[0m"
		exit 1
	fi
	lib_info="${lib_version}_${elf_arch}"
}

# check lib path then load
check_lib() {
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
	lib_libc_path="${libcList[0]}"
	# echo "$path"
	local ldList=(`find "$path" -type f -name "ld-*.so" -o -name "ld-linux*.so.2"`)
	# echo "${#ldList[@]}"
	unset IFS
	if [ ${#ldList[@]} -eq 0 ]; then
		return 1
	fi
	lib_ld_path="${ldList[0]}"
	lib_path="$path"
	return 0
}


gaio_dir=${gaio_dir%/}
if [ $# -ge 2 ]; then
	eval arg_lib="$2"
	if [ -e "$arg_lib" ]; then
		if [ -f "$arg_lib" ]; then
			extract_lib "$arg_lib"
			check_lib "$( dirname "${arg_lib}" )"
			check_lib_res="$?"
			lib_libc_path="$arg_lib"
		else
			arg_lib=${arg_lib%/}
			check_lib "$arg_lib"
			check_lib_res="$?"
			extract_lib "${lib_libc_path}"
		fi

		if [ $check_lib_res -lt 2 ]; then 
			printf "[+] Libc Info: \33[93m%s\33[0m -- %s\n" "${lib_info}" "$(dirname $lib_libc_path)/$(basename $lib_libc_path)"
			if [ $check_lib_res -gt 0 ]; then
				echo -e "\e[31m[!]\e[0m No match ld. So match in the LIBs. "
				check_lib "${gaio_dir}/${lib_info}"
				if [ $? -gt 0 ]; then 
					echo -e "\e[31m[!]\e[0m There is no match in the LIBs. "
				fi
			fi
		else
			echo -e "\e[31m[!]\e[0m The LIB Path is error. "
		fi
	else
		lib_filt="${arg_lib}"
	fi
fi

if [ -z $lib_path ]; then
	# gaio_list=$( ls -l "${gaio_dir}/" | grep '^d' | cut -c 44- )
	gaio_list=$( find "${gaio_dir}/" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; )
	if [ ! -z "$lib_filt" ]; then
		filt_res=$( echo "$gaio_list" | grep "$lib_filt" )
		if [ ${#filt_res[@]} -gt 0 ]; then
			gaio_list="${filt_res[@]}"
		else
			echo "\e[31m[!]\e[0m Lib version can not match."
		fi
	fi
	echo -e "\e[34m[?]\e[0m Choose a LIB to PATCH:"
	select obj in  "NO Patch" ${gaio_list[@]}; do
		if [ "$obj" != "NO Patch" ]; then
			lib_info="${obj}"
			path="${gaio_dir}/${obj}"
			check_lib "$path"
			break
		else
			echo "[+] Abandon Patch."
			if [ ! -z $first_try_backup ]; then
				restore_origin_file_exit
			else
				exit 2
			fi
		fi
	done
fi

# patch process
if [ -n "$lib_path" ] && [ -n "$lib_libc_path" ] && [ -n "$lib_ld_path" ]; then
	echo "Patching..."
	if [ ! "$patch_file_path" = "$backup_file_path" ]; then
		if [ -f "${patch_file_path}" ]; then
			diff "${backup_file_path}" "${patch_file_path}" > /dev/null
			if [ $? -eq 1 ]; then
				rm -f "${patch_file_path}"
			fi
		fi
		cp "${backup_file_path}" "${patch_file_path}"
	fi
	# echo $lib_path
	# echo $patch_file_path
	# echo $lib_ld_path
	patchelf --set-interpreter "${lib_ld_path}" "${patch_file_path}"
	ld_res=$?
	patchelf --set-rpath "${lib_path}" "${patch_file_path}"
	patchelf --replace-needed libc.so.6 "${lib_libc_path}" ${patch_file_path}
	rpRes=$?
	if [ $ld_res -eq 0 ] && [ $rpRes -eq 0 ]; then
		echo '[+] Done!'
		printf "Last Patch:\t\33[92m%s\33[0m \nLib Path:\t%s\n" "${lib_info}" "${lib_path}/"
		exit 0
	else
		echo 'Error: Fault in patch'
		exit 1
	fi
else
	echo "Error: No such File."
	exit 1
fi

