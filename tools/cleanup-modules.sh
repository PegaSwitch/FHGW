#!/bin/bash

pwd=`pwd`
subdir=$pwd/OpenNetworkLinux

pushd $subdir/sm/infra
if [ -f .PATCHED ]; then
    git reset --hard HEAD^
    rm .PATCHED
fi
git clean -dfx
git reset --hard
popd

pushd $subdir
if [ -f .PATCHED ]; then
    git reset --hard HEAD^^^^
    rm .PATCHED
fi
git clean -dfx
git reset --hard
popd
