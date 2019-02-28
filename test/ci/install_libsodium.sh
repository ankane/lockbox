#!/usr/bin/env bash

set -e

CACHE_DIR=$HOME/libsodium/$LIBSODIUM_VERSION

if [ ! -d "$CACHE_DIR" ]; then
  wget https://download.libsodium.org/libsodium/releases/libsodium-$LIBSODIUM_VERSION.tar.gz
  tar xvfz libsodium-$LIBSODIUM_VERSION.tar.gz
  mv libsodium-$LIBSODIUM_VERSION $CACHE_DIR
  cd $CACHE_DIR
  ./configure --prefix=$CACHE_DIR
  make
  make install
else
  echo "Libsodium cached"
fi
