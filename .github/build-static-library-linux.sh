#!/bin/bash
#
# This script is expected to be run within a Fedora 38 docker container and 
# should produce a single tarball that is the build output.

if [ $(uname -m) = "aarch64" ]; then
  export GOLANG_ARCH="arm64"
else
  export GOLANG_ARCH="amd64"
fi

TARGET="$(uname -m)-linux-musl"
GOURL="https://go.dev/dl/go1.22.0.linux-$GOLANG_ARCH.tar.gz"
ZIGURL="https://ziglang.org/download/0.11.0/zig-linux-$(uname -m)-0.11.0.tar.xz"

# Create our project directory
mkdir -p /home/tinygo-build
cd /home/tinygo-build

# install build deps
dnf install -y \
    cmake \
    git \
    ninja-build \
    which \
    binutils \
    xz

# install latest version of go
mkdir -p /usr/local
curl -s -L \
  $GOURL \
  | tar xz -C /usr/local 
export PATH=$PATH:/usr/local/go/bin

# install zig for a hermetic clang toolchain
mkdir -p /usr/local/zig
curl -s -L \
  $ZIGURL \
  | tar xJ --strip-components=1 -C /usr/local/zig
export PATH=$PATH:/usr/local/zig

# create wrapper scripts for zig compilation
echo -e "#!/bin/sh\nexec zig c++ -target $TARGET \"\$@\"" > /usr/local/bin/zigc++
echo -e "#!/bin/sh\nexec zig cc -target $TARGET \"\$@\"" > /usr/local/bin/zigcc
echo -e "#!/bin/sh\nexec zig ranlib \"\$@\"" > /usr/local/bin/ranlib
echo -e "#!/bin/sh\nexec zig ar \"\$@\"" > /usr/local/bin/ar
chmod +x /usr/local/bin/zigcc \
  /usr/local/bin/zigc++ \
  /usr/local/bin/ranlib \
  /usr/local/bin/ar

export CC=zigcc
export CXX=zigc++
export AR=ar
export RANLIB=ranlib

# Verify deps installed correctly
echo "go version installed:"
command -v go
go version
echo "zig version installed:"
command -v zig
zig version
echo "clang version installed:"
zig cc --version
env

git clone https://github.com/redpanda-data/tinygo.git .
git checkout redpanda # check out our release branch
# Clone submodules
git submodule update --init
pushd ./lib/binaryen
git apply /binaryen.patch
popd
# Clone LLVM
make llvm-source
pushd ./llvm-project
git apply /llvm-lseek64.patch
popd
make llvm-build
make release
# build output is in /home/tinygo/build/release.tar.gz
