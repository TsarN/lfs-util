#!/bin/bash
# Gross, LFS package manager
# Written by Tsarev Nikita, 2016

set -e # Stop at first error

. /etc/gross

urls=false
noinstall=false
noclean=false
noconfirm=false

function containsElement () {
    local e
    for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
    return 1
}

function installpkg {
    filename=$1
    if $urls; then
        . "$filename"
        echo $src
        return
    fi
    echo "${bold}Installing package from${normal} $filename"
    pkgdir="/var/tmp/gross/$pkgname-$pkgver"
    mkdir -p "$pkgdir"
    installdir="/var/tmp/gross/$pkgname-$pkgver-install"
    if ! $noconfirm; then
        read -p "Do you want to edit build script? [y/N] "
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ${EDITOR:-vim} "$filename"
        fi
    fi
    . "$filename"
    echo "${bold}Downloading package...${normal}"
    pkgfetch
    echo "${bold}Compiling package...${normal}"
    pkgmake
    if ! $noinstall; then
        echo "${bold}Registering package...${normal}"
        pkginstall 
        cat $filename > "/var/lib/gross/$pkgname"
        echo "files=(" >> "/var/lib/gross/$pkgname"
        cd "$installdir" && (for i in **; do # Whitespace-safe and recursive
            echo \"/$i\" >> "/var/lib/gross/$pkgname"
        done)
        echo ")" >> "/var/lib/gross/$pkgname"
        echo "asdep=$2" >> "/var/lib/gross/$pkgname"
        echo "${bold}Installing package...${normal}"
        (cd $installdir && tar -cf - *) | (cd /; tar -xvf -)
        echo "${bold}Running after-install hook${normal}"
        pkgafterinstall
    else
        echo "${bold}Skipped installation${normal}"
    fi
    if ! $noclean; then
        echo "${bold}Cleaning up...${normal}"
        rm -rf "$pkgdir" "$installdir"
    else
        echo "${bold}Skipped cleaning up${normal}"
    fi
}

function mergepkg {
    if [ $# -le 0 ]; then
        echo "No packages to merge, exiting"
        exit
    fi
    if ! $urls; then
        echo "Building dependency tree..."
    fi
    for i in "$@"; do
        builddeptree "/var/lib/gross/db/${i}"
        g_deptree+=($i)
    done
    if ! $noconfirm; then
        echo "About to merge these packages (_DEP for dependency): ${g_deptree[@]}"
        read -p "Are you sure? [y/N] "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "No packages to merge, exiting"
            return
        fi
    fi
    for i in "${g_deptree[@]}"; do
        pkg=`echo "$i" | sed -e "s/\(.*\)_DEP/\1/g"` # Removing _DEP (for dependencies)
        asdep=1
        if [ $i != $pkg ]; then asdep=0; fi;
        echo "Installing $pkg, dep=$asdep"
        if ispkginstalled "/var/lib/gross/${i}"; then
            forceunmerge=true
            unmergepkg ${i}
            forceunmerge=false
        fi
        installpkg "/var/lib/gross/db/${pkg}" $asdep
    done
}

function ispkginstalled {
    filename=$1
    if [ -f "$filename" ]; then
        return 0 # True
    else
        return 1 # False
    fi
}

function getpkgversion {
    filename=$1
    if [ -f "$filename" ]; then
        . "$filename"
        eval "$2='$pkgver'"
    fi
}

forceunmerge=false

function unmergepkg {
    if [ $# -le 0 ]; then
        echo "No packages to unmerge, exiting"
        exit
    fi
    if ! $forceunmerge; then
        echo "About to unmerge these packages: $@"
        read -p "Are you sure? [y/N] "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "No packages to unmerge, exiting"
            exit
        fi
    fi
    for i in "$@"; do
        . "${dbdir}/${i}"
        for (( idx=${#files[@]}-1 ; idx>=0 ; idx-- )) ; do
            if [[ -d ${files[idx]} ]]; then
                rmdir --ignore-fail-on-non-empty -- "${files[idx]}"
            elif [[ -f ${files[idx]} ]]; then
                rm -v -f -- "${files[idx]}"
            fi
        done
        rm -v -f -- "${dbdir}/${i}"
    done
}

g_deptree=() # builddeptree return variable

function builddeptree {
    declare dep
    declare filename=$1
    if [ -f "$filename" ]; then
        declare flag=true
        while $flag; do
            flag=false
            . "$filename"
            for dep in ${deps[@]}; do
                path="/var/lib/gross/db/${dep}"
                if [[ ! -f /var/lib/gross/${dep} ]]; then
                    if ! (containsElement ${dep} ${g_deptree[@]} || containsElement ${dep}_DEP ${g_deptree[@]}); then
                        builddeptree $path
                        g_deptree+=(${dep}_DEP)
                        flag=true
                        break
                    fi
                fi 
            done
        done
    fi
}

g_remtree=() # buildremtree return variable

function buildremtree {
    filename=$1
    echo "Building rem tree for $filename"
    if [ -f "$filename" ]; then
        . "$filename"
        flag=0
        for rem in $deps; do
            path="/var/lib/gross/db/${rem}"
            if ! (containsElement ${rem} ${g_remtree}); then
                if ! buildremtree $path; then
                    flag=1
                    break
                fi
            fi
        done
        if [ $flag -eq 0 ]; then 
            if ! (containsElement ${pkgname} ${g_remtree}); then
                g_remtree+=("${pkgname}");
            fi
        fi
        return flag
    fi
    return 0
}

shopt -s globstar

bold=$(tput bold)
normal=$(tput sgr0)

if [ $# -lt 1 ]; then
    echo "Usage: gross <operation>"
    echo "Supported operations: clean, list, list-installed, list-outdated, merge, unmerge, upgrade, info, syncinfo"
    exit
fi
pushd . > /dev/null

declare -a arguments

usage=false

for arg in "${@:1}"; do
    if [[ $arg = "--help" ]]; then
        usage=true
    elif [[ $arg = "--show-urls" ]]; then
        urls=true
    elif [[ $arg = "--noinstall" ]]; then
        noinstall=true
    elif [[ $arg = "--noclean" ]]; then
        noclean=true
    elif [[ $arg = "--noconfirm" ]]; then
        noconfirm=true
    else
        arguments+=($arg)
    fi
done

operation=${arguments[0]}

if [ "$operation" = "clean" ]; then
    if $usage; then
        echo "Usage: gross clean"
        echo "Remove temporary files"
        exit
    fi
    echo "${bold}Removing temporary files...${normal}"
    rm -rfv /var/tmp/gross/*
fi

if [ "$operation" = "info" ] || [ "$operation" = "syncinfo" ]; then
    if $usage; then
        echo "Usage: gross info/syncinfo <package>"
        echo "gross info: show information about INSTALLED package"
        echo "gross syncinfo: show information about REPOSITORY package"
        exit
    fi
    for pkg in ${arguments[@]:1}; do
        if [ "$operation" = "info" ]; then
            filename="/var/lib/gross/${pkg}"
        else
            filename="/var/lib/gross/db/${pkg}"
        fi
        if [ -f "$filename" ]; then
            . "$filename"
            echo "$pkgname-$pkgver"
            echo "Dependencies: ${deps[@]}"
            echo "Source: $src"
            echo "Website: $website"
            echo "Estimated disk usage: $diskusage"
            echo "Estimated build time: $buildtime"
            if [ "$operation" = "info" ]; then
                echo "List of installed files and directories: "
                for file in ${files[@]}; do
                    t=`grep -o "/" <<<"$file" | wc -l`
                    for i in $(seq 1 $(($t - 1))); do
                        printf "  "
                    done
                    echo $file 
                done
            fi
        else
            echo "$pkg: Package is not installed"
        fi
    done
fi

if [ "$operation" = "list-installed" ]; then
    if $usage; then
        echo "Usage: gross list-installed"
        echo "Lists all packages currently installed"
        exit
    fi
    for pkg in `ls -p /var/lib/gross | grep -v /`; do
        . /var/lib/gross/$pkg
        echo $pkgname-$pkgver
    done
fi

if [ "$operation" = "list" ]; then
    if $usage; then
        echo "Usage: gross list"
        echo "Lists all packages in repository"
        exit
    fi
    for pkg in `ls -p /var/lib/gross/db | grep -v /`; do
        . /var/lib/gross/db/$pkg
        echo $pkgname-$pkgver
    done
fi

if [ "$operation" = "unmerge" ]; then
    if $usage; then
        echo "Usage: gross unmerge <package1> [package2] ..."
        echo "Removes packages and their unneeded dependencies"
        exit
    fi
    unmergepkg "${arguments[@]:1}"
fi

if [ "$operation" = "merge" ]; then
    if $usage; then
        echo "Usage: gross merge <package1> [package2] ..."
        echo "Downloads (if neccessary) and installs packages and their dependencies"
        exit
    fi
    mergepkg "${arguments[@]:1}"
fi

if [ "$operation" = "list-outdated" ]; then
    if $usage; then
        echo "Usage: gross list-outdated"
        echo "Lists all packages that can be updated"
        exit
    fi
    for pkg in `ls -p /var/lib/gross | grep -v /`; do
        . /var/lib/gross/$pkg
        localver=$pkgver
        if [ ! -f /var/lib/gross/db/$pkg ]; then
            continue
        fi
        . /var/lib/gross/db/$pkg
        remotever=$pkgver
        if [[ "$localver" < "$remotever" ]]; then
            echo "$pkg-$localver -> $pkg-$remotever"
        fi
    done
fi

if [ "$operation" = "upgrade" ]; then
    if $usage; then
        echo "Usage: gross upgrade"
        echo "Updates all outdated packages"
        exit
    fi
    tomerge=()
    for pkg in `ls -p /var/lib/gross | grep -v /`; do
        . /var/lib/gross/$pkg
        localver=$pkgver
        if [ ! -f /var/lib/gross/db/$pkg ]; then
            continue
        fi
        . /var/lib/gross/db/$pkg
        remotever=$pkgver
        if [[ "$localver" < "$remotever" ]]; then
            tomerge+=($pkg)
        fi
    done
    mergepkg "${tomerge[@]}"
fi

popd  > /dev/null
