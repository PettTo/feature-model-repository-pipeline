#!/bin/bash
cd
rm -f /vagrant/log.txt

DUMPCONF_ENUMS=(S_UNKNOWN S_BOOLEAN S_TRISTATE S_INT S_HEX S_STRING S_OTHER P_UNKNOWN P_PROMPT P_COMMENT P_MENU P_DEFAULT P_CHOICE P_SELECT P_RANGE P_ENV P_SYMBOL E_SYMBOL E_NOT E_EQUAL E_UNEQUAL E_OR E_AND E_LIST E_RANGE E_CHOICE P_IMPLY E_NONE E_LTH E_LEQ E_GTH E_GEQ)
TAGS="rsf|dimacs|features|model|kconfigreader|tseytin"

git-clone() {
    if [[ ! -d "$1" ]]; then
        echo Cloning $2 to $1 ...
        git clone $2 $1
    fi
}

dumpconf() (
    if [ $1 = buildroot ]; then
        find ./ -type f -name "*Config.in" -exec sed -i 's/source "\$.*//g' {} \; # ignore generated Kconfig files in buildroot
    fi
    set -e
    mkdir -p /vagrant/dumpconf/$1
    yes | make allyesconfig >/dev/null || true
    args=""
    dumpconf_files=$(echo $3 | tr , ' ')
    dumpconf_dir=$(dirname $dumpconf_files | head -n1)
    for enum in ${DUMPCONF_ENUMS[@]}; do
        if grep -qrnw $dumpconf_dir -e $enum; then
            args="$args -DENUM_$enum"
        fi
    done
    if ! echo $3 | grep -q dumpconf; then
        gcc /vagrant/dumpconf.c $dumpconf_files -I $dumpconf_dir -Wall -Werror=switch $args -Wno-format -o /vagrant/dumpconf/$1/$2
        echo /vagrant/dumpconf/$1/$2
    else
        echo $3
    fi
)

kconfigreader() (
    set -e
    mkdir -p /vagrant/models/$1
    writeDimacs=--writeDimacs
    if [ $1 = freetz-ng ]; then
        touch make/Config.in.generated make/external.in.generated config/custom.in # ugly hack because freetz-ng is weird
        writeDimacs=""
    fi
    /vagrant/kconfigreader/run.sh de.fosd.typechef.kconfig.KConfigReader --fast --dumpconf $3 $writeDimacs $4 /vagrant/models/$1/$2
    echo $1,$2,$3,$4,$5 >> /vagrant/models/models.txt
)

git-run() (
    set -e
    echo >> /vagrant/log.txt
    if [[ ! -f "/vagrant/models/$1/$2.model" ]]; then
        echo -n "Reading feature model for $1 at tag $2 ..." >> /vagrant/log.txt
        cd $1
        git reset --hard
        git clean -fx
        git checkout -f $2
        kconfigreader $1 $2 $(dumpconf $1 $2 $3) $4 $5
        cd
        echo -n " done." >> /vagrant/log.txt
    else
        echo -n "Skipping feature model for $1 at tag $2" >> /vagrant/log.txt
    fi
)

svn-run() (
    set -e
    echo >> /vagrant/log.txt
    if [[ ! -f "/vagrant/models/$1/$3.model" ]]; then
        echo -n "Reading feature model for $1 at tag $3 ..." >> /vagrant/log.txt
        rm -rf $1
        svn checkout $2 $1
        cd $1
        kconfigreader $1 $3 $(dumpconf $1 $3 $4) $5 $6
        cd
        echo -n " done." >> /vagrant/log.txt
    else
        echo -n "Skipping feature model for $1 at tag $3" >> /vagrant/log.txt
    fi
)

# more information on the systems in Berger et al.'s "Variability Modeling in the Systems Software Domain"

#git-clone linux https://github.com/torvalds/linux
# for tag in $(git -C linux tag | grep -v rc | grep -v tree); do
#     if git -C ~/linux ls-tree -r $tag --name-only | grep -q arch/i386; then
#         git-run linux $tag scripts/kconfig/zconf.tab.o arch/i386/Kconfig $TAGS # in old versions, x86 is called i386
#     else
#         git-run linux $tag scripts/kconfig/zconf.tab.o arch/x86/Kconfig $TAGS
#     fi
# done

#git-clone busybox https://github.com/mirror/busybox
# for tag in $(git -C busybox tag | grep -v pre | grep -v alpha | grep -v rc); do
#     git-run busybox $tag scripts/kconfig/zconf.tab.o Config.in $TAGS
# done

# for tag in $(cd axtls; svn ls ^/tags); do
#     svn-run axtls svn://svn.code.sf.net/p/axtls/code/tags/$(echo $tag | tr / ' ') $(echo $tag | tr / ' ') config/scripts/config config/Config.in $TAGS
# done

# git-clone fiasco https://github.com/kernkonzept/fiasco
# as a workaround, use dumpconf from Linux, because it cannot be built in this repository
# git-run linux v5.0 scripts/kconfig/confdata.o,scripts/kconfig/expr.o,scripts/kconfig/preprocess.o,scripts/kconfig/symbol.o,scripts/kconfig/zconf.lex.o,scripts/kconfig/zconf.tab.o arch/x86/Kconfig $TAGS
# git-run fiasco d393c79a5f67bb5466fa69b061ede0f81b6398db /vagrant/dumpconf/linux/v5.0 src/Kconfig $TAGS

# git-clone toybox https://github.com/landley/toybox
# as a workaround, use dumpconf from Linux, because it cannot be built in this repository
# git-run linux v2.6.12 scripts/kconfig/zconf.tab.o arch/x86/Kconfig $TAGS
# for tag in $(git -C toybox tag); do
#     git-run toybox $tag /vagrant/dumpconf/linux/v2.6.12 Config.in $TAGS
# done

# git-clone uclibc-ng https://github.com/wbx-github/uclibc-ng
# for tag in $(git -C uclibc-ng tag); do
#     git-run uclibc-ng $tag extra/config/zconf.tab.o extra/Configs/Config.in $TAGS
# done

# https://github.com/zephyrproject-rtos/zephyr also uses Kconfig, but a modified dialect based on Kconfiglib, which is not compatible with kconfigreader

# https://github.com/Freetz/freetz uses Kconfig, but cannot be parsed with dumpconf, so we use freetz-ng instead (which is newer anyway)

# git-clone freetz-ng https://github.com/Freetz-NG/freetz-ng
# git-run linux v5.0 scripts/kconfig/confdata.o,scripts/kconfig/expr.o,scripts/kconfig/preprocess.o,scripts/kconfig/symbol.o,scripts/kconfig/zconf.lex.o,scripts/kconfig/zconf.tab.o arch/x86/Kconfig $TAGS
# git-run freetz-ng 88b972a6283bfd65ae1bbf559e53caf7bb661ae3 /vagrant/dumpconf/linux/v5.0 config/Config.in "rsf|features|model|kconfigreader"

git-clone buildroot https://github.com/buildroot/buildroot
git-run linux v4.17 scripts/kconfig/zconf.tab.o arch/x86/Kconfig $TAGS
for tag in $(git -C buildroot tag | grep -v rc | grep -v -e '\..*\.'); do
    git-run buildroot $tag /vagrant/dumpconf/linux/v4.17 Config.in $TAGS
done