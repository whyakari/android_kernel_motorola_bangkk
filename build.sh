#!/bin/bash
[ ! -d "toolchain" ] && echo  "installing toolchain..." && bash init_clang.sh
export KBUILD_BUILD_USER=ghazzor

PATH=$PWD/toolchain/bin:$PATH
export LLVM_DIR=$PWD/toolchain/bin
export LLVM=1
export AnyKernel3=AnyKernel3
export TIME="$(date "+%Y%m%d")"
export modpath=${AnyKernel3}/modules/vendor/lib/modules

export ARCH=arm64

if [ -z "$DEVICE" ]; then
export DEVICE=g84
fi

ARGS='
CC=clang
LD='${LLVM_DIR}/ld.lld'
ARCH=arm64
AR='${LLVM_DIR}/llvm-ar'
NM='${LLVM_DIR}/llvm-nm'
AS='${LLVM_DIR}/llvm-as'
OBJCOPY='${LLVM_DIR}/llvm-objcopy'
OBJDUMP='${LLVM_DIR}/llvm-objdump'
READELF='${LLVM_DIR}/llvm-readelf'
OBJSIZE='${LLVM_DIR}/llvm-size'
STRIP='${LLVM_DIR}/llvm-strip'
LLVM_AR='${LLVM_DIR}/llvm-ar'
LLVM_DIS='${LLVM_DIR}/llvm-dis'
LLVM_NM='${LLVM_DIR}/llvm-nm'
LLVM=1
'

make ${ARGS} O=out ${DEVICE}_defconfig moto.config
make ${ARGS} O=out -j$(nproc)

[ ! -e "out/arch/arm64/boot/Image" ] && \
echo "  ERROR : image binary not found in any of the specified locations , fix compile!" && \
exit 1

make O=out ${ARGS} -j$(nproc) INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install

#Clean Up
rm -rf ${modpath}/*
rm -rf ${AnyKernel3}/{Image, dtb, dtbo.img}
rm -rf ${AnyKernel3}/*.zip

#Setup
mkdir -p ${modpath}
kver=$(make kernelversion)
kmod=$(echo ${kver} | awk -F'.' '{print $3}')

#Copy stuff
cp out/.config ${AnyKernel3}/config
cp out/arch/arm64/boot/Image ${AnyKernel3}/Image
cp out/arch/arm64/boot/dtb.img ${AnyKernel3}/dtb
cp out/arch/arm64/boot/dtbo.img ${AnyKernel3}/dtbo.img
cp build.sta/${DEVICE}_modules.blocklist ${modpath}/modules.blocklist
cp $(find out/modules/lib/modules/5.4* -name '*.ko') ${modpath}/
cp out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} ${modpath}/
cp out/modules/lib/modules/5.4*/modules.order ${modpath}/modules.load

#Edit
sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' ${modpath}/modules.dep
#sed -i 's/.*\//.ko/g' ${AnyKernel3}/modules/vendor/lib/modules/modules.load
#sed -i 's#.*/##; s/\.ko$//' ${AnyKernel3}/modules/vendor/lib/modules/modules.load
sed -i 's/.*\///; s/\.ko$//' ${modpath}/modules.load

source build.sta/${DEVICE}_mdconf
for useles_modules in "${modules_to_nuke[@]}"; do
  grep -vE "$useles_modules" ${modpath}/modules.load > /tmp/templd && mv /tmp/templd ${modpath}/modules.load
done

#Zip
cd ${AnyKernel3}
zip -r9 O_KERNEL.${kmod}_${DEVICE}-${TIME}.zip * -x .git README.md *placeholder
