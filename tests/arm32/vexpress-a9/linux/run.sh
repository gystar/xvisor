#[1. Build environment for Xvisor]
export CROSS_COMPILE=arm-linux-gnueabi-
export xvisor_source_directory="/space/guiyi/project/xvisor/"
export linux_src_directory="/space/guiyi/project/linux-5.4.72/"
export linux_build_directory=$linux_src_directory"build/"
export busybox_rootfs_directory="/space/guiyi/project/busybox-1_31_stable/"

#[2. GoTo Xvisor source directory]
cd $xvisor_source_directory

#[3. Configure Xvisor with Generic v7 default settings]
make ARCH=arm generic-v7-defconfig

#[4. Build Xvisor & DTBs]
make -j$(nproc)

#[5. Build Basic Firmware]
make -C tests/arm32/vexpress-a9/basic -j$(nproc)

# [6. GoTo Linux source directory]
cd $linux_source_directory

#[7. Configure Linux in build directory]
sed -i 's/0xff800000UL/0xff000000UL/' arch/arm/include/asm/pgtable.h
cp arch/arm/configs/vexpress_defconfig arch/arm/configs/tmp-vexpress-a9_defconfig
../xvisor/tests/common/scripts/update-linux-defconfig.sh -p arch/arm/configs/tmp-vexpress-a9_defconfig -f ../xvisor/tests/arm32/vexpress-a9/linux/linux_extra.config
make O=$linux_build_directory ARCH=arm tmp-vexpress-a9_defconfig -j$(nproc)

 # [8. Build Linux in build directory]
make O=$linux_build_directory ARCH=arm Image dtbs -j$(nproc)

# [9. Patch Linux kernel to replace sensitive non-priviledged instructions]
$xvisor_source_directory/arch/arm/cpu/arm32/elf2cpatch.py -f $linux_build_directory/vmlinux | $xvisor_source_directory/build/tools/cpatch/cpatch32 $linux_build_directory/vmlinux 0

# [10. Extract patched Linux kernel image]
${CROSS_COMPILE}objcopy -O binary $linux_build_directory/vmlinux $linux_build_directory/arch/arm/boot/Image

#[11. Create BusyBox RAMDISK to be used as RootFS for Linux kernel]
#  (Note: For subsequent steps, we will assume that your RAMDISK is located at <busybox_rootfs_directory>/rootfs.img)
#  (Note: Please refer tests/common/busybox/README.md for creating rootfs.img using BusyBox)
cp tests/common/busybox/busybox-1.31.1_defconfig $busybox_source_directory/.config
cd $busybox_source_directory
make oldconfig
make install -j$(nproc)
mkdir -p ./_install/etc/init.d
mkdir -p ./_install/dev
mkdir -p ./_install/proc
mkdir -p ./_install/sys
ln -sf /sbin/init ./_install/init
cp -f $xvisor_source_directory/tests/common/busybox/fstab ./_install/etc/fstab
cp -f $xvisor_source_directory/tests/common/busybox/rcS ./_install/etc/init.d/rcS
cp -f $xvisor_source_directory/tests/common/busybox/motd ./_install/etc/motd
cp -f $xvisor_source_directory/tests/common/busybox/logo_linux_clut224.ppm ./_install/etc/logo_linux_clut224.ppm
cp -f $xvisor_source_directory/tests/common/busybox/logo_linux_vga16.ppm ./_install/etc/logo_linux_vga16.ppm

#[12. GoTo Xvisor source directory]
cd $xvisor_source_directory

#[13. Create disk image for Xvisor]
mkdir -p ./build/disk/tmp
mkdir -p ./build/disk/system
cp -f ./docs/banner/roman.txt ./build/disk/system/banner.txt
cp -f ./docs/logo/xvisor_logo_name.ppm ./build/disk/system/logo.ppm
mkdir -p ./build/disk/images/arm32/vexpress-a9
dtc -q -I dts -O dtb -o ./build/disk/images/arm32/vexpress-a9-guest.dtb ./tests/arm32/vexpress-a9/vexpress-a9-guest.dts
cp -f ./build/tests/arm32/vexpress-a9/basic/firmware.bin.patched ./build/disk/images/arm32/vexpress-a9/firmware.bin
cp -f ./tests/arm32/vexpress-a9/linux/nor_flash.list ./build/disk/images/arm32/vexpress-a9/nor_flash.list
cp -f ./tests/arm32/vexpress-a9/linux/cmdlist ./build/disk/images/arm32/vexpress-a9/cmdlist
cp -f ./tests/arm32/vexpress-a9/xscript/one_guest_vexpress-a9.xscript ./build/disk/boot.xscript
cp -f $linux_build_directory/arch/arm/boot/Image ./build/disk/images/arm32/vexpress-a9/Image
cp -f $linux_build_directory/arch/arm/boot/dts/vexpress-v2p-ca9.dtb ./build/disk/images/arm32/vexpress-a9/vexpress-v2p-ca9.dtb
cp -f $busybox_rootfs_directory/rootfs.img ./build/disk/images/arm32/vexpress-a9/rootfs.img
genext2fs -B 1024 -b 32768 -d ./build/disk ./build/disk.img

#[14. Launch QEMU]
qemu-system-arm -M vexpress-a9 -m 512M -display none -serial stdio -kernel build/vmm.bin -dtb build/arch/arm/board/generic/dts/arm/vexpress-v2p-ca9.dtb -initrd build/disk.img

#[15. Kick Guest0 for starting Basic Firmware]
XVisor# guest kick guest0

#[16. Bind to virtual UART0 of Linux Guest]
XVisor# vserial bind guest0/uart0

#[17. Copy linux from NOR flash to RAM and start linux booting from RAM]
[guest0/uart0] basic# autoexec
#(Note: "autoexec" is a short-cut command)
#(Note: The <xvisor_source_directory>/tests/arm32/vexpress-a9/linux/cmdlist file
#which we have added to guest NOR flash contains set of commands for booting
#linux from NOR flash)

#[18. Wait for Linux prompt to come-up and then try out some commands]
[guest0/uart0] / # ls

#[19. Enter character seqence 'ESCAPE+x+q" return to Xvisor prompt]
  [guest0/uart0] / #

#(Note: replace all <> brackets based on your workspace)
#(Note: some of the above steps will need to be adapted for other
#   types of ARM host)
#  (Note: for more info on your desired ARM host refer docs/arm/)
#  (Note: you are free to change the ordering of above steps based
#   on your workspace)
