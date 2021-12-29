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
export CCACHE_DIR=$HOME/.ccache

########### #################################################################
# OPENSSL # #################################################################
########### #################################################################

OPENSSL_VERSION=1.1.1m

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

RUST_VERSION=1.58.1
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
	patch -p1 < $PATCHES/rust/0001-Add-armv7_unknown_linux_uclibceabi-target.patch
	./x.py
	./build/x86_64-unknown-linux-gnu/stage0/bin/cargo update -p libc
	touch .patched
fi

if [ ! -f .installed ]; then

	CARGO_TARGET_ARMV7_UNKNOWN_LINUX_UCLIBCEABI_RUSTFLAGS='-Clink-arg=-s -Clink-arg=-Wl,--dynamic-linker=/mmc/lib/ld-uClibc.so.1 -Clink-arg=-Wl,-rpath,/mmc/lib' \
	ARMV7_UNKNOWN_LINUX_UCLIBCEABI_OPENSSL_LIB_DIR=$DEST/lib \
	ARMV7_UNKNOWN_LINUX_UCLIBCEABI_OPENSSL_INCLUDE_DIR=$DEST/include \
	ARMV7_UNKNOWN_LINUX_UCLIBCEABI_OPENSSL_NO_VENDOR=1 \
	ARMV7_UNKNOWN_LINUX_UCLIBCEABI_OPENSSL_STATIC=1 \
	DESTDIR=$BASE/install \
	./x.py install
	touch .installed
fi

cd $BASE

if [ ! -f .prepped ]; then
	mkdir -p ./install/DEBIAN
	cp $SRC/rust/control ./install/DEBIAN
	sed -i 's,version,'"$RUST_VERSION"'-'"$RUST_VERSION_REV"',g' ./install/DEBIAN/control
	touch .prepped
fi

if [ ! -f .packaged ]; then
	dpkg-deb --build install
	dpkg-name install.deb
	touch .packaged
fi
