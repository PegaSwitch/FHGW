# Override OpenNetworkLinux's packages

overrides="base/amd64/kernels/kernel-4.19-lts-x86-64-all base/amd64/upgrade"
for d in $overrides; do
    if [ -f $ONL/packages/$d/PKG.yml ]; then
        touch $ONL/packages/$d/PKG.yml.disabled
    fi
done
