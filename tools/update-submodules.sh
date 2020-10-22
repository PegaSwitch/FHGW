# Override OpenNetworkLinux's packages

overrides="base/amd64/kernels/kernel-4.19-lts-x86-64-all base/amd64/upgrade"
for d in $overrides; do
    if [ -f $ONL/packages/$d/PKG.yml ]; then
        touch $ONL/packages/$d/PKG.yml.disabled
    fi
done

#FIXME: workaround for build platform code outside OpenNetworkLinux

if [ -h $ONLBASE/packages/platforms/pegatron ]; then
    rm $ONLBASE/packages/platforms/pegatron
fi
if [ ! -h $ONL/packages/platforms/pegatron ]; then
    (cd $ONL/packages/platforms && ln -s ../../../tools/platforms/pegatron pegatron)
fi

