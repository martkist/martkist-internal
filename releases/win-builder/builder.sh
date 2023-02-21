
  WRAP_DIR=$HOME/wrapped
  CONFIGFLAGS="--enable-reduce-exports --disable-bench --disable-gui-tests"
  FAKETIME_HOST_PROGS="g++ ar ranlib nm windres strip objcopy"
  FAKETIME_PROGS="date makensis zip"
  HOST_CFLAGS="-O2 -g"
  HOST_CXXFLAGS="-O2 -g"
  REFERENCE_DATETIME="2023-01-01 00:00:00"
  REFERENCE_DATE="2023-01-01"
  REFERENCE_TIME="00:00:00"
  export QT_RCC_TEST=1
  export GZIP="-9n"
  export TAR_OPTIONS="--mtime="$REFERENCE_DATE\\\ $REFERENCE_TIME""
  export TZ="UTC"
  export BUILD_DIR=`pwd`
  mkdir -p ${WRAP_DIR}

  export ZERO_AR_DATE=1

  # Create global faketime wrappers
  for prog in ${FAKETIME_PROGS}; do
    echo '#!/bin/bash' > ${WRAP_DIR}/${prog}
    echo "REAL=\`which -a ${prog} | grep -v ${WRAP_DIR}/${prog} | head -1\`" >> ${WRAP_DIR}/${prog}
    echo 'export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1' >> ${WRAP_DIR}/${prog}
    echo "export FAKETIME=\"${REFERENCE_DATETIME}\"" >> ${WRAP_DIR}/${prog}
    echo "\$REAL \$@" >> $WRAP_DIR/${prog}
    chmod +x ${WRAP_DIR}/${prog}
  done

  # Create per-host faketime wrappers
for prog in ${FAKETIME_HOST_PROGS}; do
    echo '#!/bin/bash' > ${WRAP_DIR}/${HOST}-${prog}
    echo "REAL=\`which -a ${HOST}-${prog} | grep -v ${WRAP_DIR}/${HOST}-${prog} | head -1\`" >> ${WRAP_DIR}/${HOST}-${prog}
    echo 'export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1' >> ${WRAP_DIR}/${HOST}-${prog}
    echo "export FAKETIME=\"${REFERENCE_DATETIME}\"" >> ${WRAP_DIR}/${HOST}-${prog}
    echo "\$REAL \$@" >> $WRAP_DIR/${HOST}-${prog}
    chmod +x ${WRAP_DIR}/${HOST}-${prog}
done

# Create per-host linker wrapper
# This is only needed for trusty, as the mingw linker leaks a few bytes of
# heap, causing non-determinism. See discussion in https://github.com/martkist/martkist/pull/6900

mkdir -p ${WRAP_DIR}/${HOST}
for prog in collect2; do
    echo '#!/bin/bash' > ${WRAP_DIR}/${HOST}/${prog}
    REAL=$(${HOST}-gcc -print-prog-name=${prog})
    echo "export MALLOC_PERTURB_=255" >> ${WRAP_DIR}/${HOST}/${prog}
    echo "${REAL} \$@" >> $WRAP_DIR/${HOST}/${prog}
    chmod +x ${WRAP_DIR}/${HOST}/${prog}
done
for prog in gcc g++; do
    echo '#!/bin/bash' > ${WRAP_DIR}/${HOST}-${prog}
    echo "REAL=\`which -a ${HOST}-${prog} | grep -v ${WRAP_DIR}/${HOST}-${prog} | head -1\`" >> ${WRAP_DIR}/${HOST}-${prog}
    echo 'export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1' >> ${WRAP_DIR}/${HOST}-${prog}
    echo "export FAKETIME=\"${REFERENCE_DATETIME}\"" >> ${WRAP_DIR}/${HOST}-${prog}
    echo "export COMPILER_PATH=${WRAP_DIR}/${HOST}" >> ${WRAP_DIR}/${HOST}-${prog}
    echo "\$REAL \$@" >> $WRAP_DIR/${HOST}-${prog}
    chmod +x ${WRAP_DIR}/${HOST}-${prog}
done

export PATH=${WRAP_DIR}:${PATH}

# Create the release tarball using (arbitrarily) the first host
./autogen.sh
CONFIG_SITE=${HOSTPREFIX}/share/config.site ./configure --prefix=/
make dist
SOURCEDIST=`echo martkistcore-*.tar.gz`
DISTNAME=`echo ${SOURCEDIST} | sed 's/.tar.*//'`

# Correct tar file order
mkdir -p temp
pushd temp
tar xf ../$SOURCEDIST
find martkistcore-* | sort | tar --no-recursion --mode='u+rw,go+r-w,a+X' --owner=0 --group=0 -c -T - | gzip -9n > ../$SOURCEDIST
mkdir -p $OUTDIR/src
cp ../$SOURCEDIST $OUTDIR/src
popd

ORIGPATH="$PATH"
# Extract the release tarball into a dir for each host and build

export PATH=${BASEPREFIX}/${HOST}/native/bin:${ORIGPATH}
mkdir -p distsrc-${HOST}
cd distsrc-${HOST}
INSTALLPATH=`pwd`/installed/${DISTNAME}
mkdir -p ${INSTALLPATH}
tar --strip-components=1 -xf ../$SOURCEDIST

CONFIG_SITE=${BASEPREFIX}/${HOST}/share/config.site ./configure --prefix=/ --disable-ccache --disable-maintainer-mode --disable-dependency-tracking --with-qt-bindir=$QTNATIVE/bin --with-qt-translationdir=$QTDIR/translations ${CONFIGFLAGS} CFLAGS="${HOST_CFLAGS}" CXXFLAGS="${HOST_CXXFLAGS}"
make ${MAKEOPTS}
make ${MAKEOPTS} -C src check-security
make deploy
make install DESTDIR=${INSTALLPATH}
cp -f martkistcore-*setup*.exe $OUTDIR/
cd installed
find . -name "lib*.la" -delete
find . -name "lib*.a" -delete
rm -rf ${DISTNAME}/lib/pkgconfig
find ${DISTNAME}/bin -type f -executable -exec ${i}-objcopy --only-keep-debug {} {}.dbg \; -exec ${i}-strip -s {} \; -exec ${i}-objcopy --add-gnu-debuglink={}.dbg {} \;
find ${DISTNAME} -not -name "*.dbg"  -type f | sort | zip -X@ ${OUTDIR}/${DISTNAME}-${i}.zip
find ${DISTNAME} -name "*.dbg"  -type f | sort | zip -X@ ${OUTDIR}/${DISTNAME}-${i}-debug.zip
cd ../../
rm -rf distsrc-${i}

cd $OUTDIR
rename 's/-setup\.exe$/-setup.exe/' *-setup.exe
find . -name "*-setup.exe" | sort | tar --no-recursion --mode='u+rw,go+r-w,a+X' --owner=0 --group=0 -c -T - | gzip -9n > ${OUTDIR}/${DISTNAME}-win-unsigned.tar.gz
mv ${OUTDIR}/${DISTNAME}-x86_64-*-debug.zip ${OUTDIR}/${DISTNAME}-win64-debug.zip
mv ${OUTDIR}/${DISTNAME}-x86_64-*.zip ${OUTDIR}/${DISTNAME}-win64.zip
