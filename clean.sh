#!/bin/bash
DATE=`date +%y%m%d`
RELEASE=`lsb_release -a | grep Codename | cut -f 2`
usage(){
    printf "`basename $0`: A bash script to clean a system before a Debian release upgrade."
    printf "\nFormat: `basename $0` [-f] [-o] [-l] [-h]"
    printf "\nOptions:\n\t-f, --force\t-> Remove non-official package, leftover configuration files and hold packages without asking\n\t-o, --log-output\t-> Log performed commands in a log file in current directory\n\t-l, --list\t\t-> List non-official package, leftover configuration files and hold packages and exit\n\t-h, --help\t\t-> Print this help output\n"
    printf "\n\nNon-official package, leftover configuration files and hold packages will be listed and user will be asked to remove or keep fot each one.\nAt the end the 'dpkg --audit' command is performed."
}
yesno(){
    while true ; do
        read -p "$1 (Type \"y/n\"):" input
        case $input in
            [yY]*) echo 'YES!'; return;;
            [nN]*) echo; return;;
        esac
    done
}
nonofficial(){
    NOOUT=`apt-forktracer`; [[ $? -eq 127 ]] && echo "Error, apt-forktracer is not installed!" && return
    [[ -z $NOOUT ]] && echo "No non-official package" && return
    printf "Non-official packages:\n"; apt-forktracer
    [[ $LISTONLY ]] && [[ ! $MAKELOG ]] && return
    [[ $MAKELOG ]] && echo "Non-Official:" >> $LOGFILE && apt-forktracer | sort >> $LOGFILE && [[ $LISTONLY ]] && return
    for pkg in `apt-forktracer | sort | cut -d ' ' -f 1`; do [[ $FORCE || `yesno "Do you want to remove '$pkg'?"` ]] && apt-get $FORCE remove $pkg; done
}
leftover(){
    [[ -z `find /etc -name '*.dpkg-*' -o -name '*.ucf-*' -o -name '*.merge-error'` ]] && echo "No leftover" && return
    [[ $LISTONLY ]] && find /etc -name '*.dpkg-*' -o -name '*.ucf-*' -o -name '*.merge-error' && [[ ! $MAKELOG ]] && return
    [[ $MAKELOG ]] && echo "Leftover:" >> $LOGFILE && find /etc -name '*.dpkg-*' -o -name '*.ucf-*' -o -name '*.merge-error' && [[ $LISTONLY ]] && return
    for file in `find /etc -name '*.dpkg-*' -o -name '*.ucf-*' -o -name '*.merge-error'`; do  [[ $FORCE || `yesno "Do you want to remove '$file'?"` ]] && rm -rf $file; done
}
holdpkg(){
    [[ -z `dpkg --get-selections | grep 'hold$'` ]] && echo "No hold package" && return
    [[ $LISTONLY ]] && dpkg --get-selections | grep 'hold$' && [[ ! $MAKELOG ]] && return
    [[ $MAKELOG ]] && dpkg --get-selections | grep 'hold$' >> $LOGFILE && [[ $LISTONLY ]] && return
    for pkg in `dpkg --get-selections | grep 'hold$'`; do  [[ $FORCE || `yesno "Do you want to remove '$pkg'?"` ]] && apt-get $FORCE remove $pkg; done
}
auditpkg(){
    [[ -z `dpkg --audit` ]] && echo "No broken install" && return
    [[ $LISTONLY ]] && dpkg --audit && [[ ! $MAKELOG ]] && return
    [[ $MAKELOG ]] && dpkg --audit >> $LOGFILE && [[ $LISTONLY ]] && return
    dpkg --audit; echo "Follow instructions above to fix broken or unconfigured install and check it again with the following command 'dpkg --audit'"
}
while [[ $# -ge 1 ]]; do
    case $1 in
        -h|"--help") usage; exit 0;;
        -f|"--force") FORCE='-y'; shift;;
        -o|"--log-output") MAKELOG='true'; LOGFILE="$RELEASE-clean_$DATE.log"; shift;;
        -l|"--list") LISTONLY='true'; shift;;
        *) echo "Unknown option: $1"; usage; exit 1
    esac
done
echo "Cleaning..."; nonofficial; leftover; holdpkg; auditpkg; echo "Done"
