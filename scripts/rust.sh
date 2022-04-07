#!/bin/bash

set -e
set -x

BASE=`pwd`
SRC=$BASE/src
PATCHES=$BASE/patches
RPATH=$PREFIX/lib
DEST=$BASE$PREFIX
LDFLAGS="-L$DEST/lib -s -Wl,--dynamic-linker=$PREFIX/lib/ld-uClibc.so.1 -Wl,-rpath,$RPATH -Wl,-rpath-link,$DEST/lib"
CPPFLAGS="-I$DEST/include"
CFLAGS=$EXTRACFLAGS
CXXFLAGS=$CFLAGS
CONFIGURE="./configure --prefix=$PREFIX --host=$DESTARCH-linux"
MAKE="make -j`nproc`"
export CCACHE_DIR=$HOME/.ccache_rust

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

OPENSSL_VERSION=1.1.1n

cd $SRC/openssl

if [ ! -f .extracted ]; then
	rm -rf openssl openssl-${OPENSSL_VERSION}
	tar zxvf openssl-${OPENSSL_VERSION}.tar.gz
	mv openssl-${OPENSSL_VERSION} openssl
	touch .extracted
fi

cd openssl

if [ ! -f .configured ]; then
	./Configure linux-armv4 -march=armv7-a -mtune=cortex-a9 \
	-Wl,--dynamic-linker=$PREFIX/lib/ld-uClibc.so.1 \
	-Wl,-rpath,$RPATH -Wl,-rpath-link=$RPATH \
	--prefix=$PREFIX
	touch .configured
fi

if [ ! -f .built ]; then
	make CC=$DESTARCH-linux-gcc
	touch .built
fi

if [ ! -f .installed ]; then
	make install CC=$DESTARCH-linux-gcc INSTALLTOP=$DEST OPENSSLDIR=$DEST/ssl
	touch .installed
fi

######## ####################################################################
# RUST # ####################################################################
######## ####################################################################

RUST_VERSION=1.60.0
RUST_VERSION_REV=1

cd $SRC/rust

if [ ! -f .cloned ]; then
	git clone https://github.com/rust-lang/rust.git
	touch .cloned
fi

cd rust

if [ ! -f .configured ]; then
	git checkout $RUST_VERSION
	cp ../config.toml .
	touch .configured
fi

if [ ! -f .patched ]; then
	./x.py
	./build/x86_64-unknown-linux-gnu/stage0/bin/cargo update -p libc
	touch .patched
fi

if [ ! -f .installed ]; then

	CARGO_TARGET_ARMV7_UNKNOWN_LINUX_UCLIBCEABI_RUSTFLAGS='-Clink-arg=-s -Clink-arg=-Wl,--dynamic-linker=/mmc/lib/ld-uClibc.so.1 -Clink-arg=-Wl,-rpath,/mmc/lib' \
	CFLAGS_armv7_unknown_linux_uclibceabi="-march=armv7-a -mtune=cortex-a9" \
	CXXFLAGS_armv7_unknown_linux_uclibceabi="-march=armv7-a -mtune=cortex-a9" \
	CFLAGS_mipsel_unknown_linux_uclibc="-mips32 -mtune=mips32" \
	CXXFLAGS_mipsel_unknown_linux_uclibc="-mips32 -mtune=mips32" \
	ARMV7_UNKNOWN_LINUX_UCLIBCEABI_OPENSSL_LIB_DIR=$DEST/lib \
	ARMV7_UNKNOWN_LINUX_UCLIBCEABI_OPENSSL_INCLUDE_DIR=$DEST/include \
	ARMV7_UNKNOWN_LINUX_UCLIBCEABI_OPENSSL_NO_VENDOR=1 \
	ARMV7_UNKNOWN_LINUX_UCLIBCEABI_OPENSSL_STATIC=1 \
	DESTDIR=$BASE/armv7-unknown-linux-uclibceabi \
	./x.py install
	touch .installed
fi

cd $BASE

if [ ! -f .prepped ]; then
	mkdir -p $BASE/armv7-unknown-linux-uclibceabi/DEBIAN \
		 $BASE/mipsel-unknown-linux-uclibc/DEBIAN \
		 $BASE/mipsel-unknown-linux-uclibc/mmc/lib/rustlib
	cp $SRC/rust/control $BASE/armv7-unknown-linux-uclibceabi/DEBIAN
	cp $SRC/rust/control_mipsel $BASE/mipsel-unknown-linux-uclibc/DEBIAN/control
	sed -i 's,version,'"$RUST_VERSION"'-'"$RUST_VERSION_REV"',g' \
		$BASE/armv7-unknown-linux-uclibceabi/DEBIAN/control \
		$BASE/mipsel-unknown-linux-uclibc/DEBIAN/control
	mv armv7-unknown-linux-uclibceabi/mmc/lib/rustlib/mipsel-unknown-linux-uclibc \
	   armv7-unknown-linux-uclibceabi/mmc/lib/rustlib/manifest-rust-std-mipsel-unknown-linux-uclibc \
	   armv7-unknown-linux-uclibceabi/mmc/lib/rustlib/manifest-rust-analysis-mipsel-unknown-linux-uclibc \
	   $BASE/mipsel-unknown-linux-uclibc/mmc/lib/rustlib
	touch .prepped
fi

if [ ! -f .packaged ]; then
	dpkg-deb --build armv7-unknown-linux-uclibceabi
	dpkg-name armv7-unknown-linux-uclibceabi.deb
	dpkg-deb --build mipsel-unknown-linux-uclibc
	dpkg-name mipsel-unknown-linux-uclibc.deb
	touch .packaged
fi
