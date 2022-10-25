#!/bin/bash
DATE=`date +%y%m%d`
RELEASE=`lsb_release -a | grep Codename | cut -f 2`
FILENAME="$RELEASE-upgrade_$DATE"
TMP="/tmp"
DEFAULT_FILES=("/etc" "/var/lib/dpkg" "/var/lib/apt/extended_states")
DEFAULT_HOME_ROOT="/home"
usage(){
    printf "`basename $0`: A bash script to perform a system backup before a Debian release upgrade."
    printf "\nFormat: `basename $0` [--no-default ARG] [-h] [ARG...]"
    printf "\n\nARG:\tFiles or directories to backup"
    printf "\nOptions:\n\t--no-default\t\t\t-> Do not perform the default backup, ARG becomes mandatory\n\t--noget-selected\t-> Don't add the output of 'dpkg --get-selected \"*\"' to '.backlist' file\n\t-h, --help\t\t\t\t-> Print this help output"
    printf "\n\nThis scirpt generates a tarball compressed in GZIP with all backed up files and directories.\nA '.backlist' file is generated at the root of the tarball and contain the output of 'ls -gGaARhB' on all backed up files.\nThe output of 'dpkg --get-selected \"*\"' is added to the '.backlist' file."
    printf "\n\nDefault backup:\n\tSome files and directories are backed up by default according to Debian release-notes documentation:\n\t\t- '/etc'\n\t\t- '/var/lib/dpkg'\n\t\t- '/var/lib/apt/extend_sates'\n\t\tAll hiden files in users home directory"
    printf "\n\nError code:\n\t1: Syntax error during invocation\n\t2: Error during generation\n"
}
setdefault(){
    DEFAULT+=("${DEFAULT_FILES[@]}")
    for home in $DEFAULT_HOME_ROOT/*; do
        if [[ -d $home ]]; then
            for file in $home/.*; do
                [[ $file == "$home/." || $file == "$home/.." ]] || DEFAULT+=("$file");
            done
        fi
    done
}
genref(){
    echo -e "Debian release upgrade for $RELEASE: `date`\nTar file: '$FILENAME.tar.gz'\n" > ./$FILENAME.backlist
    for file in "${FILES[@]}"; do ls -gGaARhB "$file" >> $TMP/$FILENAME.backlist; done
    [[ $NOGET_SELECTED ]] && return
    echo -e "\nDPKG get-selected *:" >> $TMP/$FILENAME.backlist
    dpkg --get-selections "*" >> $TMP/$FILENAME.backlist
}
tardirs(){
    [[ $NOGET_SELECTED ]] && getselected='' || getselected=$TMP/$FILENAME.backlist
    tar -c --file="./$FILENAME.tar" $TMP/$FILENAME.backlist
    for file in "${FILES[@]}"; do tar --append --file="./$FILENAME.tar" "$file"; done
    gzip ./$FILENAME.tar > ./$FILENAME.tar.gz
}
while [[ $1 == '-'* ]]; do
    case $1 in
        -h|"--help") usage; exit 0;;
        --no-default) NODEFAULT='true'; shift;;
        --noget-selected) NOGET_SELECTED='true'; shift;;
        -*) echo "Unknown option: $1"; usage; exit 1
    esac
done
[[ ! $NODEFAULT ]] && setdefault && FILES+=("${DEFAULT[@]}")
[[ $NODEFAULT && ! $1 ]] && echo "Syntax error: ARG must be passed with option '--no-default'"
[[ "$*" ]] && for arg in "$@"; do [[ ! -d $arg && ! -f $arg ]] && echo "Syntax Error: $arg is not a regular file or directory!" && exit 1; done
FILES+=("$@")
echo "Generating '$TMP/$FILENAME.backlist' file:..." && genref && echo "Done" || exit 2
echo "Generating './$FILENAME.tar.gz' file:..." && tardirs && echo "Done" || exit 2
