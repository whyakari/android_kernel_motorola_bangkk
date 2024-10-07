# SPDX-License-Identifier: GPL-2.0-or-later
#
# Makefile for the linux exFAT filesystem support.
#
obj-$(CONFIG_EXFAT_FS) += exfat.o

exfat-y	:= inode.o namei.o dir.o super.o fatent.o cache.o nls.o misc.o \
	file.o balloc.o exfat_core.o exfat_super.o exfat_api.o exfat_blkdev.o exfat_cache.o \
	exfat_data.o exfat_bitmap.o exfat_nls.o exfat_oal.o exfat_upcase.o
