#!/bin/sh
# Script to build R-base with rtools40
set -e
set -x

pacman -S --needed --noconfirm wget subversion gcc

# Install system libs
pacman -Syu --noconfirm
pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-{gcc,gcc-fortran,icu,libtiff,libjpeg,libpng,pcre2,xz,bzip2,zlib,cairo,tk,curl,libwebp}
pacman -S --needed --noconfirm mingw-w64-ucrt-x86_64-openblas

# download and unpack the Tcl/Tk bundle
TCLBUNDLE=tcltk-5550-5412.zip

if [ -f "$TCLBUNDLE" ];
then
    echo "$TCLBUNDLE exists."
else
    wget https://mirrors.tuna.tsinghua.edu.cn/CRAN/bin/windows/Rtools/rtools43/files/$TCLBUNDLE
fi


# Put pdflatex on the path (needed only for CMD check)
export PATH=/x86_64-w64-mingw32.static.posix/bin:$PATH
export PATH=$HOME/AppData/Local/Programs/MiKTeX/miktex/bin/x64:$PATH
export TAR="/usr/bin/tar"
export TAR_OPTIONS="--force-local"

pdflatex --version || true
texindex --version
make --version

# get absolute paths
srcdir=$(dirname $(realpath $0))

VERLOC=$(svn info trunk | grep Revision: | awk '{print $2}')
VERREM=$(svn info https://svn.r-project.org/R/trunk | grep Revision: | awk '{print $2}')

if [ -d "${srcdir}/trunk" ]; then
    if [ $VERLOC = $VERREM ]; then
        echo "no changed, skip build."
        exit 0
    else
        echo "remote updated, run svn update."
        svn update ${srcdir}/trunk
        echo "make clean and rebuild"
        cd "${srcdir}/trunk/src/gnuwin32"
        make clean
    fi

else
    echo "repo not exists, run svn checkout."
    svn checkout https://svn.r-project.org/R/trunk
fi

cd "${srcdir}/trunk"
unzip -o ../$TCLBUNDLE

# Add custom patches here:
patch -Np1 -i "${srcdir}/blas.diff"


cd src/gnuwin32
sed -e "s|@texindex@|$(cygpath -m $(which texindex))|"  "${srcdir}/MkRules.local.in" > MkRules.local

make rsync-recommended
make all recommended

make distribution
#make check-all 2>&1 | tee ${srcdir}/check.log

# Copy to home dir
cd ${srcdir}
cp -v trunk/src/gnuwin32/installer/R-devel-win.exe ./R-devel-win-${VERREM}.exe
installer=$(ls *.exe)
echo "::set-output name=installer::$installer"
echo "Done: $installer"
