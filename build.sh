#!/bin/bash
[ ! -d "toolchain" ] && echo  "installing toolchain..." && bash init_clang.sh
export KBUILD_BUILD_USER=ghazzor
SECONDS=0
PATH=$PWD/toolchain/bin:$PATH
export LLVM_DIR=$PWD/toolchain/bin
export LLVM=1
AK3_DIR="$HOME/AnyKernel3"
DEFCONFIG="bangkk_defconfig"
ZIPNAME="MoeKernel-bangkk-$(date '+%Y%m%d-%H%M').zip"
export modpath=${AnyKernel3}/modules/vendor/lib/modules
export ARCH=arm64

if [ -z "$DEVICE" ]; then
export DEVICE=g84
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make $MAKE_PARAMS $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-m" || $1 = "--menu" ]]; then
    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG menuconfig
elif [[ $1 = "menu" ]]; then
    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG menuconfig
else
    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG
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

make ${ARGS} O=out $DEFCONFIG moto.config
make ${ARGS} O=out -j$(nproc)

[ ! -e "out/arch/arm64/boot/Image" ] && \
echo "  ERROR : image binary not found in any of the specified locations , fix compile!" && \
exit 1

make O=out ${ARGS} -j$(nproc) INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install

echo -e "\nKernel compiled succesfully! Zipping up...\n"
if [ -d "$AK3_DIR" ]; then
	cp -r $AK3_DIR AnyKernel3
	git -C AnyKernel3 checkout bangkk &> /dev/null
elif ! git clone -q https://github.com/MoeKernel/AnyKernel3 -b bangkk; then
	echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
	exit 1
fi

rm -rf ${modpath}/*
rm -rf AnyKernel3/{Image, dtb, dtbo.img}
rm -rf AnyKernel3/*.zip

mkdir -p ${modpath}
kver=$(make kernelversion)
kmod=$(echo ${kver} | awk -F'.' '{print $3}')

mkdir -p AnyKernel3/modules/vendor/lib/modules 
kver=$(make kernelversion)
kmod=$(echo ${kver} | awk -F'.' '{print $3}')
cp out/.config AnyKernel3/config
cp out/arch/arm64/boot/Image AnyKernel3/Image
cp out/arch/arm64/boot/dtb.img AnyKernel3/dtb
cp out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
# cp build.sta/${DEVICE}_modules.blocklist ${modpath}/modules.blocklist
cp $(find out/modules/lib/modules/5.4* -name '*.ko') ${modpath}/
cp out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} ${modpath}/
cp out/modules/lib/modules/5.4*/modules.order ${modpath}/modules.load

sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' ${modpath}/modules.dep
sed -i 's/.*\///; s/\.ko$//' ${modpath}/modules.load

source build.sta/${DEVICE}_mdconf
for useles_modules in "${modules_to_nuke[@]}"; do
  grep -vE "$useles_modules" ${modpath}/modules.load > /tmp/templd && mv /tmp/templd ${modpath}/modules.load
done

cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
cd ..
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"
curl -F "file=@$ZIPNAME" https://temp.sh/upload
