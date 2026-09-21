#
# Copyright (C) 2022 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/inoi/INOI_A75

# Inherit from mt6789-common
include device/alldocube/mt6789-common/BoardConfigCommon.mk

# Assert
TARGET_OTA_ASSERT_DEVICE := INOI_A75,A750,INOI_A75_Elegance,INOI_A750

# Init
TARGET_INIT_VENDOR_LIB := libinit_INOI_A75
TARGET_RECOVERY_DEVICE_MODULES := libinit_INOI_A75

# Dynamic Partitions (from lpdump.txt & ID V7)
BOARD_SUPER_PARTITION_SIZE := 9663676416
BOARD_SUPER_PARTITION_GROUPS := sysretq0_dynamic_partitions
BOARD_SYSRETQ0_DYNAMIC_PARTITIONS_SIZE := 9661579264
BOARD_SYSRETQ0_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    odm_dlkm \
    product \
    system \
    system_ext \
    vendor \
    vendor_dlkm

# TWRP Configs
TW_DEVICE_VERSION := INOI_A750_ID_U_V7_20260822
OF_MAINTAINER := sysretq0


# Device Resolution
override TARGET_SCREEN_WIDTH := 1080
override TARGET_SCREEN_HEIGHT := 2460
override OF_SCREEN_H := 2460

# Language test
#override TW_DEFAULT_LANGUAGE := ru
# override TW_DEFAULT_LANGUAGE := en   # fallback, если ru не найдётся при сборке

# Statusbar
override TW_STATUS_ICONS_ALIGN := center
override TW_CUSTOM_CPU_POS := "300"
override TW_CUSTOM_CLOCK_POS := "70"
override TW_CUSTOM_BATTERY_POS := "790"

# CPU Temp
override TW_CUSTOM_CPU_TEMP_PATH := /sys/devices/virtual/thermal/thermal_zone25/temp

# Brightness
override TW_DEFAULT_BRIGHTNESS := 102
override TW_MAX_BRIGHTNESS := 255
