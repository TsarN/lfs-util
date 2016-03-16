#!/bin/bash
# Gross, LFS package manager
# Written by Tsarev Nikita, 2016

set -e # Stop at first error

urls=false
nomake=false
nofetch=false
noinstall=false
noclean=false
noconfirm=false

. /etc/gross

if [[ $EUID -ne 0 ]]; then
    sourcedir="$HOME/.local/src"
fi

mkdir -p $sourcedir
mkdir -p $dbdir{,/db,/conf}

function _testpkg() {
    if [[ -f $dbdir/$1 ]]; then
        echo $2
    else
        echo $3
    fi
}

function vercomp() {
    # 0 =
    # 1 >
    # 2 <
    if [[ $1 = $2 ]]; then return 0; fi
    for i in `printf "$1\n$2" | sort -V`; do
        if [[ $i = $2 ]]; then return 1; else return 2; fi
    done
}

function as_root() {
    if   [ $EUID = 0 ]; then $*
    elif [ -x /usr/bin/sudo ]; then sudo $* 
    else su -c \\"$*\\" 
    fi 
}

function pullfromsvn() {
    cd /tmp 
    mkdir -p gross
    cd gross
    for name in {LFS,BLFS}; do 
        wget "http://svn.linuxfromscratch.org/$name/trunk/BOOK/packages.ent" -O packages.ent.$name >/dev/null 2>&1
cat packages.ent.$name | grep '^<!ENTITY' |  sed -e 's/<!--.*-->//' -e 's/^<!ENTITY \(.*\) \+"\(.*\)">/\1 \2/' | grep -v "^%" | sed "/-->/d" | sed 's/<!--.*$//g' > pkglist.$name 
grep -ho --color=none "&[a-zA-Z0-9-]\+;" pkglist.$name | sort | uniq | sed 's/^&\(.*\);$/\1/' > pkgent.$name
for i in `cat pkgent.$name`; do grep "^$i" pkglist.$name --color=none | sed 's|\([a-zA-Z0-9-]\+\) \+\([^ ]\+\)|s@\\\&\1;@\2@g|'; done > pkgsed.$name
sed -f pkgsed.$name pkglist.$name | grep 'version ' | sed 's/-version//g' | sed 's/ \+/ /g' | sed 's/^ \+//g' | sed 's/ \+$//g' | sed 's/ /=/' > pkgres.$name
for ii in `cat pkgres.$name`; do pkg=`echo "$ii" | grep -o --color=none '^[^=]\+'`; if [[ -f "/var/lib/gross/db/$pkg" ]]; then . "/var/lib/gross/db/$pkg"; printf "pkgv=" > /tmp/gross.tmp; echo "$ii" | sed 's@^[^=]\+=\(.*\)$@\1@' >> /tmp/gross.tmp; . /tmp/gross.tmp; rm /tmp/gross.tmp; if [[ "$pkgver" != "$pkgv" ]]; then echo "$pkg: $pkgver -> $pkgv"; fi; fi; done 
        if ! $noclean; then
            rm packages.ent.$name pkglist.$name pkgent.$name pkgsed.$name pkgres.$name
        fi
    done
}

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
    unset -f pkgfetch
    . "$filename"
    echo "${bold}Installing package from${normal} $filename"
    pkgdir="/var/tmp/gross/$pkgname-$pkgver"
    mkdir -p "$pkgdir"
    installdir="/var/tmp/gross/$pkgname-$pkgver-install"
    mkdir -pv $installdir
    if ! $noconfirm; then
        read -p "Do you want to edit build script? [y/N] "
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            as_root ${EDITOR:-vim} "$filename"
            . "$filename"
        fi
    fi
    if ! $nomake; then
        if ! $nofetch; then
            if [[ `type -t pkgfetch` = "function" ]]; then
                echo "${bold}Downloading and unpacking package...${normal}"
                pkgfetch
            else
                progress=0
                for file in ${src[@]}; do
                    progress=$((progress + 1))
                    echo "${bold}Downloading ${normal}${file} ${bold}($progress/${#src[@]})${normal}"
                    if [[ "$file" == http* ]] || [[ "$file" == ftp* ]]; then
                        if [[ ! -f ${sourcedir}/$(basename $file) ]]; then
                            #wget "$file" -O "${sourcedir}/$(basename $file)"
                            rm -f "${sourcedir}/.$(basename $file).PART"
                            wget "$file" -O "${sourcedir}/.$(basename $file).PART"
                            mv "${sourcedir}/.$(basename $file).PART" "${sourcedir}/$(basename $file)"
                        fi
                    fi
                    if [[ "$file" == git* ]]; then cd "$pkgdir" && git clone "$file"; fi
                    if [[ "$file" == svn* ]]; then cd "$pkgdir" && svn co "$file"; fi
                    echo "${bold}Extracting ${normal}$(basename $file)"
                    if [[ "$file" == *.tar.xz  ]]; then tar -xf "${sourcedir}/$(basename $file)" -C $pkgdir; 
                    elif [[ "$file" == *.tar.gz  ]]; then tar -xf "${sourcedir}/$(basename $file)" -C $pkgdir; 
                    elif [[ "$file" == *.tgz  ]]; then tar -xf "${sourcedir}/$(basename $file)" -C $pkgdir; 
                    elif [[ "$file" == *.tar.bz2 ]]; then tar -xf "${sourcedir}/$(basename $file)" -C $pkgdir; 
                    elif [[ "$file" == *.tar ]]; then tar -xf "${sourcedir}/$(basename $file)" -C $pkgdir; 
                    elif [[ "$file" == *.zip ]]; then cd $pkgdir && unzip "${sourcedir}/$(basename $file)"; 
                    elif [[ "$file" == *.rar ]]; then cd $pkgdir && unrar e "${sourcedir}/$(basename $file)"; 
                    elif [[ "$file" == *.exe ]]; then cd $pkgdir && cabextract "${sourcedir}/$(basename $file)"; 
                    elif [[ -f "$sourcedir/$(basename $file)" ]]; then cp -r "${sourcedir}/$(basename $file)" "${pkgdir}"; fi
                done
            fi
        else
            echo "${bold}Skipped downloading${normal}"
        fi
        echo "${bold}Compiling package...${normal}"
        pkgmake
    else
        echo "${bold}Skipped compiling${normal}"
        if [[ -d "$pkgdir/$pkgname-$pkgver" ]]; then
            cd $pkgdir/$pkgname-$pkgver
        fi
    fi
    if ! $noinstall; then
        echo "${bold}Registering package...${normal} - $installdir"
        pkginstall 
        pkg=`echo "$i" | sed -e "s/\(.*\)_DEP/\1/g"` # Removing _DEP (for dependencies)
        if ispkginstalled "${pkg}"; then
            forceunmerge=true
            unmergepkg ${pkg}
            forceunmerge=false
        fi
        filename=$1
        cp "$filename" "/tmp/gross.tmp"
        echo "files=(" >> "/tmp/gross.tmp"
        cd "$installdir" && (for i in **; do 
            echo \"/$i\" >> "/tmp/gross.tmp"
        done)
        echo ")" >> "/tmp/gross.tmp"
        echo "asdep=$2" >> "/tmp/gross.tmp"
        echo "${bold}Installing package...${normal}"
        as_root cp -v "/tmp/gross.tmp" "${dbdir}/$pkgname"
        rm /tmp/gross.tmp
        echo "(cd $installdir && tar -cf - *) | (cd /; tar -xvf -)" > /tmp/gross.tmp
        as_root bash /tmp/gross.tmp
        rm /tmp/gross.tmp
        echo "${bold}Running after-install hook${normal}"
        as_root $0 trigger-post-install-hook $pkgname
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
    for II in "$@"; do
        builddeptree "${dbdir}/db/${II}"
        g_deptree+=($II)
        if $buildtreefail; then
            exit 1
        fi
    done
    if ! $noconfirm; then
        echo "About to merge these packages:"
        for i in ${g_deptree[@]}; do 
            pkg=`echo "$i" | sed -e "s/\(.*\)_DEP/\1/g"`
            getpkgversion "${dbdir}/db/${pkg}"
            printf "${pkg}-${pkgver}"
            if [[ -f "${dbdir}/${pkg}" ]]; then
                version=$pkgver
                sed -e '/^files=/q' -ne '$ !p' < "${dbdir}/${pkg}" > /tmp/gross.tmp
                . /tmp/gross.tmp
                rm /tmp/gross.tmp 
                set +e
                vercomp "$pkgver" "$version"
                vcmp=$?
                if [[ $vcmp -eq 2 ]]; then
                    echo " -- upgrading"
                fi
                if [[ $vcmp -eq 1 ]]; then
                    echo " -- downgrading"
                fi
                if [[ $vcmp -eq 0 ]]; then
                    echo " -- reinstalling"
                fi
                set -e
            else
                echo ""
            fi
        done
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
        installpkg "${dbdir}/db/${pkg}" $asdep
    done
}

function ispkginstalled {
    if [ -f "${dbdir}/$1" ]; then
        return 0 # True
    else
        return 1 # False
    fi
}

function getpkgversion {
    filename=$1
    if [ -f "$filename" ]; then
        grep "^pkgver" < "$filename" > /tmp/gross.tmp
        . "/tmp/gross.tmp"
        rm /tmp/gross.tmp
    else
        pkgname=$(basename $1)
        pkgver=0
    fi
}

forceunmerge=false

function unmergepkg {
    if [ $# -le 0 ]; then
        echo "No packages to unmerge, exiting"
        exit
    fi
    if ! $forceunmerge; then
        if ! $noconfirm; then
            echo "About to unmerge these packages: $@"
            read -p "Are you sure? [y/N] "
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "No packages to unmerge, exiting"
                exit
            fi
        fi
    fi
    for i in "$@"; do
        echo "${bold}Uninstalling${normal} $i"
        . "${dbdir}/${i}"
        for (( idx=${#files[@]}-1 ; idx>=0 ; idx-- )) ; do
            if [[ -d ${files[idx]} ]]; then
                as_root rmdir --ignore-fail-on-non-empty -- "${files[idx]}"
            elif [[ -f ${files[idx]} ]]; then
                as_root rm -v -f -- "${files[idx]}"
            fi
        done
        as_root rm -v -f -- "${dbdir}/${i}"
    done
}

sstatus=0

function isdepsatisfiable {
# Return values:
# 0 - already satisfied
# 1 - can't satisfy
# 2 - requires installing from database

    pkg=$1

    if [ -f "${dbdir}/$pkg" ]; then
        sstatus=0; return
    fi

    if [ -f "${dbdir}/db/$pkg" ]; then
        sstatus=2; return
    fi

    # Here magic happens: we check versions
    echo "$pkg" | sed -n 's/^\([a-zA-Z0-9-]\+\)\(>=\|<=\|=\|<\|>\)\(.*\)$/_pkgname="\1"\n_pkgif="\2"\n_pkgver="\3"/p' > /tmp/gross.tmp
    if [[ ! -s /tmp/gross.tmp ]]; then
        sstatus=1; return
        rm -f /tmp/gross.tmp
    fi
    . /tmp/gross.tmp
    rm /tmp/gross.tmp

    _pkgifnot=""

    if [ "${_pkgif}" = "<=" ]; then
        _pkgifnot="! "
        _pkgif=">"
    fi

    if [ "${_pkgif}" = ">=" ]; then
        _pkgifnot="! "
        _pkgif="<"
    fi

    if [[ $_pkgif = "<" ]]; then _pkgif=2; fi
    if [[ $_pkgif = ">" ]]; then _pkgif=1; fi
    if [[ $_pkgif = "=" ]]; then _pkgif=0; fi
    
    if [ -f "${dbdir}/${_pkgname}" ]; then
        sed -e '/^files=/q' -ne '$ !p' < "${dbdir}/${_pkgname}" > /tmp/gross.tmp
        . /tmp/gross.tmp
        rm /tmp/gross.tmp 

        set +e
        vercomp "$pkgver" "$_pkgver"
        if [ $_pkgifnot $? -eq $_pkgif ]; then
            set -e
            sstatus=0; return
        fi
        set -e
    fi

    if [ -f "${dbdir}/db/${_pkgname}" ]; then
        . "${dbdir}/db/${_pkgname}"
        set +e
        vercomp "$pkgver" "$_pkgver"
        if [ $_pkgifnot $? -eq $_pkgif ]; then
            set -e
            sstatus=2; return
        fi
        set -e
    fi
    sstatus=1; return
}

g_deptree=() # builddeptree return variable
buildtreefail=false

function builddeptree {
    declare dep
    declare filename=$1
    if [ -f "$filename" ]; then
        declare flag=true
        while $flag; do
            flag=false
            . "$filename"
            for dep in ${deps[@]}; do
                path="${dbdir}/db/${dep}"
                isdepsatisfiable "${dep}"
                if [[ $sstatus -eq 1 ]]; then
                    echo "Unable to satisfy dependency ${bold}${dep}${normal}"
                    buildtreefail=true
                fi
                if [[ $sstatus -eq 2 ]]; then
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
            path="${dbdir}/db/${rem}"
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
    echo "Supported operations: clean, list, list-installed, list-outdated, find-file, merge, unmerge, upgrade, info, syncinfo, check-updates"
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
    elif [[ $arg = "--nomake" ]]; then
        nomake=true
    elif [[ $arg = "--nofetch" ]]; then
        nofetch=true
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
    rm -rf /var/tmp/gross/*
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
            filename="${dbdir}/${pkg}"
        else
            filename="${dbdir}/db/${pkg}"
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
                    echo $file 
                done
            fi
        else
            echo "$pkg: Package is not installed"
        fi
    done
fi

if [ "$operation" = "find-file" ]; then
    if $usage; then
        echo "Usage: gross find-file <path>"
        echo "Find packages that own specified file"
        exit
    fi
    for pkg in `ls -p ${dbdir} | grep -v /`; do
        . ${dbdir}/$pkg
        for file in ${files[@]}; do
            if [ "$file" = "${arguments[1]}" ]; then
                echo $pkgname-$pkgver
            fi
        done
    done
fi

if [ "$operation" = "list-installed" ]; then
    if $usage; then
        echo "Usage: gross list-installed"
        echo "Lists all packages currently installed"
        exit
    fi
    for pkg in `ls -p ${dbdir} | grep -v /`; do
        sed -e '/^files=/q' -ne '$ !p' < "${dbdir}/$pkg" > /tmp/gross.tmp
        . /tmp/gross.tmp
        rm /tmp/gross.tmp 
        echo $pkgname-$pkgver
    done
fi

if [ "$operation" = "list" ]; then
    if $usage; then
        echo "Usage: gross list"
        echo "Lists all packages in repository"
        exit
    fi
    for pkg in `ls -p ${dbdir}/db | grep -v /`; do
        . ${dbdir}/db/$pkg
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

if [ "$operation" = "install" ]; then
    if $usage; then
        echo "Usage: gross install <filename>"
        echo "Install ONE package and DO NOT check it's dependencies"
        exit
    fi
    installpkg "${arguments[1]}"
fi

if [ "$operation" = "list-outdated" ]; then
    if $usage; then
        echo "Usage: gross list-outdated"
        echo "Lists all packages that can be updated"
        exit
    fi
    for pkg in `ls -p ${dbdir} | grep -v /`; do
        sed -e '/^files=/q' -ne '$ !p' < "${dbdir}/$pkg" > /tmp/gross.tmp
        . /tmp/gross.tmp
        rm /tmp/gross.tmp 
        localver=$pkgver
        if [ ! -f ${dbdir}/db/$pkg ]; then
            continue
        fi
        . ${dbdir}/db/$pkg
        remotever=$pkgver
        set +e
        vercomp "$localver" "$remotever"
        if [[ $? -eq 2 ]]; then
            echo "$pkg-$localver -> $pkg-$remotever"
        fi
        set -e
    done
fi

if [ "$operation" = "upgrade" ]; then
    if $usage; then
        echo "Usage: gross upgrade"
        echo "Updates all outdated packages"
        exit
    fi
    tomerge=()
    for pkg in `ls -p ${dbdir} | grep -v /`; do
        sed -e '/^files=/q' -ne '$ !p' < "${dbdir}/$pkg" > /tmp/gross.tmp
        . /tmp/gross.tmp
        rm /tmp/gross.tmp 
        localver=$pkgver
        if [ ! -f ${dbdir}/db/$pkg ]; then
            continue
        fi
        . ${dbdir}/db/$pkg
        remotever=$pkgver
        set +e
        vercomp "$localver" "$remotever"
        if [[ $? -eq 2 ]]; then
            tomerge+=($pkg)
        fi
        set -e
    done
    mergepkg "${tomerge[@]}"
fi

if [ "$operation" = "new-package" ]; then
    cp -v ${dbdir}/db/dummy "${dbdir}/db/${arguments[1]}"
    sed -i "s@^pkgname=@pkgname=${arguments[1]}@" "${dbdir}/db/${arguments[1]}"
    vim "${dbdir}/db/${arguments[1]}"
fi

if [ "$operation" = "trigger-post-install-hook" ]; then
    . "${dbdir}/db/${arguments[1]}"
    pkgafterinstall
fi

if [ "$operation" = "check-updates" ]; then
    pullfromsvn
fi

popd  > /dev/null
