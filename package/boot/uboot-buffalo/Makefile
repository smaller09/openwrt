#
# Copyright (C) 2010-2014 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_VERSION:=2023.10
PKG_RELEASE:=11

PKG_HASH:=e00e6c6f014e046101739d08d06f328811cebcf5ae101348f409cbbd55ce6900

include $(INCLUDE_DIR)/u-boot.mk
include $(INCLUDE_DIR)/package.mk

define U-Boot/Default
  BUILD_TARGET:=kirkwood
  BUILD_SUBTARGET:=generic
endef

define U-Boot/lswsxl
  NAME:=Buffalo Linkstation LS-WSXL
  BUILD_DEVICES:=buffalo_lswsxl
endef

UBOOT_TARGETS := \
	lswsxl

define Build/Configure
	$(if $(findstring _second_stage,$(BUILD_VARIANT)),
		$(CP) \
			$(PKG_BUILD_DIR)/configs/$(subst _second_stage,,$(BUILD_VARIANT))_defconfig \
			$(PKG_BUILD_DIR)/configs/$(BUILD_VARIANT)_defconfig
		echo CONFIG_SECOND_STAGE=y >> $(PKG_BUILD_DIR)/configs/$(BUILD_VARIANT)_defconfig
	)
	+$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR) \
		$(BUILD_VARIANT)_config V=1
endef

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C $(PKG_BUILD_DIR) \
		u-boot.kwb \
		CROSS_COMPILE=$(TARGET_CROSS)
	mkimage -A $(ARCH) -O linux -T kernel -C none \
		-a 0x600000 -e 0x600000 \
		-n 'U-Boot uImage' \
		-d $(PKG_BUILD_DIR)/u-boot.bin $(PKG_BUILD_DIR)/u-boot.img
endef

define Package/u-boot/install
	$(CP) \
		$(PKG_BUILD_DIR)/u-boot.bin \
		$(PKG_BUILD_DIR)/u-boot.kwb \
		$(PKG_BUILD_DIR)/u-boot.img \
		$(1)/
endef

define Build/InstallDev
	$(INSTALL_DIR) $(STAGING_DIR_HOST)/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/tools/kwboot $(STAGING_DIR_HOST)/bin/
endef

$(eval $(call BuildPackage/U-Boot))
