#!/bin/bash

# help
docs="Search ROPgadget with assembly instruction and register in ELF. 
Default output the common Rop Gadget.
Usage:\t$0 [OPTION] ELF [reg]...
Options:
\t-h, --help\tPrint Display this help and exit
\t-a, --asm\tAssign the assembly instruction what you want. It will be used as an argument to the \"ROPgadget --only\"
Args:
\tELF\tthe ELF file to find Rop Gadget. It will be used as an argument to the \"ROPgadget --binary\"
\treg\tMatch the REGISTERs.

Example:
\t$0 ./pwn
\t$0 ./pwn rdi rsi
\t$0 -a 'lea|ret' ./pwn
\t$0 ./pwn -a 'mov|ret' 
\t$0 ./pwn -a 'pop|ret' rdi rsi
"

reg_rul_def_32="int 0x80|eax|ebx|ecx|edx|esi|edi|ebp"
reg_rul_def_64="syscall|rax|rdi|rsi|rdx|rcx|r10|r8|r9"
reg_rul_def="leave|: \Kret|$reg_rul_def_64|$reg_rul_def_32"
asm_def="leave|int|syscall|pop|ret"

usage() {
    echo -e "$docs"
    exit 1
}

paras=$(getopt -o ha: -l help,asm: -n $(basename $0) -- "$@")
set -- $paras
# echo "$@"
while [ $1 ];
do
    case $1 in
    -a | --asm)
		eval asm=$2
        shift 2
        verbose=y
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
eval elfName=$1
# echo "$elfName"
if [ ! -f "$elfName" ]; then
	echo -e "\e[31m[!] ELF file is illegal.\e[0m"
	exit 1
else
	elfName="$(dirname $elfName)/$(basename $elfName)"
fi



if [ $# -ge 2 ];then
	shift
	eval reg=($@)
	# echo "${reg[*]}"
	IFS="|"
    # echo "${#reg[@]}"
	regRul=$(echo "${reg[*]}")
    unset IFS
fi
asm=${asm:-$asm_def}
regRul=${regRul:-$reg_rul_def}

printf "[+] ROPgadget | ELF: %s\n" "$elfName"
# asm=${asm:-}
# drawLine "Gadgets in $2"
ropRes=$( ROPgadget --multibr --binary "$elfName" --only "$asm" )

if [[ "$regRul" != "ret" ]]; then
	ropRes=$( echo "$ropRes" | grep -v ": ret .*" )
fi
echo "$ropRes" | grep -P "$regRul" --color=always
amount=$(echo "$ropRes" | grep -cE "$regRul")

printf "[-] End -- Found \33[31m%d\33[0m ROP gadget\n" "$amount"

