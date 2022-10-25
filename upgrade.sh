#!/bin/bash
# Bash script to perform Debian release upgrade step by step.
#
# Uncomment the next line to force '-y' option:
# DONOTASK='true'
# Uncomment the next line to force '-f' option:
# FORCE='-y'
#
STEPS_NUMBER=6
usage(){
    printf "`basename $0`: A bash script to perform Debian release upgrade step by step.\n"
    printf "\nFormat: `basename $0` [-c STEP_NUMBER|-s STEP_NUMBER|-e STEP_NUMBER] [-y] [-h] SOURCE_FILE\n"
    printf "\nArgs:\n\tSOURCE_FILE\t-> Path to the future sources.list file (this file need to contain debian package repositories for the targeted Debian release)\n"
    printf "\nOptions:\n\t-c STEP_NUMBER\t-> Run script from the step with number STEP_NUMBER and continue to end (do not run a step without having performed previous steps)\n\t-s STEP_NUMBER\t-> Run the step with number STEP_NUMBER and exit (do not run a step without having performed previous steps)\n\t-e STEP_NUMBER\t-> Start from the beginning and exit script after the step with number STEP_NUMBER\n\t-y\t-> Answer 'Yes' to all script questions, but still wait answer for apt-get questions (only use it if you don't care about Warnings)\n\t-f\t-> Same as '-y' option but add the '-y' parameter to all apt-get commands (only use it with a strong backup system)\n\t-h\t-> Print this help output\n"
    printf "\nSteps:\n\tThis script splits the release upgrade in several steps identified with an integer (1 to 6):\n\t1: Update package repositories\n\t2: Full upgrade the system\n\t3: Replace sources.list with the SOURCE_FILE sources.list\n\t4: Update new package repositories\n\t5: Make an upgrade of the system\n\t6: Make the full-upgrade to finis\n"
    printf "\nError code:\n\t1: Syntax error during invocation\n\t2: Error during 'apt-get update' command\n\t3: Error during 'apt-get upgrade' command\n\t4: Error during 'apt-get full-upgrade' command\n\t5: Error during sources.list manipulation\n"
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
errout(){
    printf "Something goes wrong, please check the output above to understand what's happened!\n You have to fix the problem before processing!\nThen you will be able to continue this release upgrade using the command below:\n\t$0 $SOURCE_FILE -c $1"
    exit $2
}
stepone(){
    step=1
    printf "!!!!WARNING!!!!\nIt's recommended to make a system backup before a release upgrade!!\n"
    [[ $DONOTASK ]] || [[ `yesno "Do you want to continue?"` ]] || exit 0
    printf "Let's show you'r actual Debian release: "; lsb_release -a
    printf "\n\nStarting this release upgrade with an update of package repositories...\n"
    apt-get update || errout  $step 2
    printf "Done, but take care for Warning lines in the output above!\n"
}
steptwo(){
    step=2
    printf "\nNext step is a full-upgrade of your packages. "
    [[ $DONOTASK ]] || [[ `yesno "Are you ready (it may take a while?)"` ]] || exit 0
    apt-get upgrade -y || errout  $step 3
    apt-get full-upgrade -y || errout  $step 4
    nodisplay=`apt-get autoremove -y`
    printf "Done, take a look for Warning lines in the output above!\n"
}
stepthree(){
    step=3
    if [[ $1 == 'undo' ]]; then
        mv /etc/apt/sources.list.olddebian /etc/apt/sources.list || errout  $step 4
        printf "Undone\nTo retry directly before the sources.list file replacement, run the following command:\n\t$0 SOURCE_FILE -c $step"
        exit 0
    fi
    printf "\nYou're sources.list file will be replaced for this new one:\n"; cat $SOURCE_FILE
    printf "\nYou're old sources.list file will be renamed as 'sources.list.old' (and sources.list.d as sources.list.d.old).\n"
    [[ $DONOTASK ]] || [[ `yesno "Are you agree for this change?"` ]] || exit 0
    cp /etc/apt/sources.list /etc/apt/sources.list.olddebian || errout  $step 5
    mv /etc/apt/sources.list.d /etc/apt/sources.list.d.old && mkdir /etc/apt/sources.list.d || errout  $step 5
    cp $SOURCE_FILE /etc/apt/sources.list || errout  $step 5
    printf "Done\n"
}
stepfour(){
    step=4
    URL="https://wiki.debian.org/fr/SourcesList"
    printf "\n!!!!WARNING!!!!\nYou're system will need you for these next steps!\nHave a coffee before if that is necessary ;) "
    [[ $DONOTASK ]] || read -p "Press ENTER when ready..."
    printf "Let's check you're new sources.list file with an new update of package repositories...\n"
    apt-get update || errout  $step 2
    printf "Done, but take care for Warning lines especially in the output above!\nIf you doubt what you see, go for a walk on this URL: $URL\n"
    printf "If you start to sweat, don't worry, it's still time to undo the sources.list replacement. You will came back and will try again directly from step 3.\n"
    [[ $DONOTASK ]] || [[ `yesno "Are you sure to continue (if not, sources.list replacement will be undo)?"` ]] || stepthree undo
    printf "Okay!\n"

}
stepfive(){
    step=5
    printf "\nNow you'r system will be upgrade to the new release of Debian.\n!!!!WARNING!!!!\nDuring this step, the package manager will ask you some questions about configuration files and services restart, among other things.\nDon't stay away from keyboard for too long, because you'r upgrade will wait for you before progressing.\nYou will take another break before next step\n"
    [[ $DONOTASK ]] || read -p "Press ENTER when ready, and answer these next questions..."
    apt-get upgrade $FORCE || errout $step 3
    printf "Done\nTake a look to Warning lines above, "
    [[ $DONOTASK ]] || [[ `yesno "can we continue?"` ]] || exit 0
    printf "Well done!\n"
}
stepsix(){
    step=6
    printf "\nNext, is time for the full-upgrade of you'r new Debian system.\nTake a break, last step will ask you some similar questions.\n"
    [[ $DONOTASK ]] || read -p "Press ENTER when ready, and answer these next questions..."
    apt-get full-upgrade $FORCE || errout  $step 4
    nodisplay=`apt-get autoremove -y`
    if [[ ! $DONOTASK ]]; then [[ `yesno "No Warning lines in the output above?"` ]] && finish || finish 'help';
    else printf "Done\n";
    fi
}
finish(){
    URL1="https://www.debian.org/releases/`lsb_release -a | grep Codename | cut -f 2`/`dpkg --print-architecture`/release-notes/ch-whats-new.html"
    URL2="https://www.debian.org/releases/`lsb_release -a | grep Codename | cut -f 2`/`dpkg --print-architecture`/release-notes/"
    printf "\nWell, let's show you'r new Debian release: "; lsb_release -a
    [[ $DONOTASK ]] && printf "\nLook for Warning lines in the output above.\n"
    [[ $1 == 'help' || $DONOTASK ]] && printf "If there are blocking problems that you do not know how to solve, you might find useful information at the following URL:\n\t$URL2\n"
    [[ $1 != 'help' ]] && printf "Keep you informed of what's new at the following URL:\n\t$URL1\n"
}
runsteps(){
    case $1 in
        1) stepone;;
        2) steptwo;;
        3) stepthree;;
        4) stepfour;;
        5) stepfive;;
        6) stepsix;;
        *) stepone; steptwo; stepthree; stepfour; stepfive; stepsix
    esac
}
checkstep(){
    echo $1 | grep -E ^[0-6]$ && return
    echo "Syntax Error: this option need a valid step number see usage with '--help' option!"; exit 1
}
main(){
    if [[ $1 == 'continue' ]]; then s=$2; while [[ $s -le $STEPS_NUMBER ]]; do runsteps $s; s=$(($s+1)); done
    elif [[ $1 == 'exitat' ]]; then s=1; while [[ $s -le $2 ]]; do runsteps $s; s=$(($s+1)); done
    elif [[ $1 == 'dostep' ]]; then runsteps $2
    else runsteps; fi
}
case $1 in
    -h|"--help") usage; exit 0;;
    -y) DONOTASK='true'; shift;;
    -f) FORCE='-y'; DONOTASK='true'; shift;;
esac
case $1 in
    -c) MODE='continue'; checkstep $2; STEP=$2; shift; shift;;
    -e) MODE='exitat'; checkstep $2; STEP=$2; shift; shift;;
    -s) MODE='dostep'; checkstep $2; STEP=$2; shift; shift;;
    -*) echo "Unknown option: $1"; usage; exit 1
esac
[[ ! -f $1 ]] && echo "Syntax Error: SOURCE_FILE need a valid existing file" && exit 1 || SOURCE_FILE=$1
main $MODE $STEP
