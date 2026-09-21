#
# Copyright (C) 2022 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from INOI_A75 device
$(call inherit-product, device/inoi/INOI_A75/device.mk)

# Inherit some common TWRP stuff.
$(call inherit-product, vendor/twrp/config/common.mk)

# Product Specifics
PRODUCT_NAME := twrp_INOI_A75
PRODUCT_DEVICE := INOI_A75
PRODUCT_BRAND := INOI
PRODUCT_MODEL := A750
PRODUCT_MANUFACTURER := INOI_Limited

PRODUCT_GMS_CLIENTID_BASE := android-inoi

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRODUCT_NAME=INOI_A75_Elegance \
    PRODUCT_DEVICE=INOI_A75_Elegance \
    BUILD_FINGERPRINT="INOI/INOI_A75_Elegance/INOI_A75_Elegance:14/UP1A.231005.007/60821:user/release-keys" \
    PRIVATE_BUILD_DESC="INOI/INOI_A75_Elegance/INOI_A75_Elegance:14/UP1A.231005.007/60821:user/release-keys"
