# Decryption baseline — INOI_A75, NEEA firmware

Reference snapshot of everything the recovery's decryption path depends on,
taken from a working device where both default-password decryption and PIN
unlock succeed. Keep it to diff against another firmware variant (IN) when a
decryption problem is reported there — the diff is the answer, guessing is not.

Taken from: NEEA_U_V6, system security patch 2026-09-05.

## Security HALs (vendor)

| HAL | format | version | source file |
|---|---|---|---|
| `android.hardware.gatekeeper` | HIDL | **1.0** | `manifest.xml` |
| `android.hardware.security.keymint` | AIDL | **1** (no version attribute) | `android.hardware.security.keymint-service.trustkernel.xml` |
| `android.hardware.security.secureclock` | AIDL | 1 | `...secureclock-service.trustkernel.xml` |
| `android.hardware.security.sharedsecret` | AIDL | 1 | `...sharedsecret-service.trustkernel.xml` |
| `vendor.mediatek.hardware.keymaster_attestation` | HIDL | 1.1 | `manifest.xml` |

Implementation is **trustkernel** throughout (`ro.hardware.gatekeeper=trustkernel`,
service `vendor.keymint-trustkernel`).

OrangeFox detects this at runtime and logs `Using keymaster version '4.1'`.
`OF_DEFAULT_KEYMASTER_VERSION` is deliberately **not** set in vendorsetup.sh —
hard-coding it is what would break a different firmware.

## /data encryption (vendor fstab)

`/vendor/etc/fstab.mt6789`, line 29:

```
/dev/block/by-name/userdata /data f2fs
  noatime,nosuid,nodev,discard,noflush_merge,fsync_mode=nobarrier,
  reserve_root=134217,resgid=1065,inlinecrypt
  wait,check,formattable,quota,latemount,resize,reservedsize=128m,checkpoint=fs,
  fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized,
  keydirectory=/metadata/vold/metadata_encryption,fsverity
```

The parts that matter for decryption:

- `fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized` — FBE v2 policy
- `keydirectory=/metadata/vold/metadata_encryption` — metadata encryption key
- `inlinecrypt` — inline crypto engine
- `ro.crypto.volume.filenames_mode=aes-256-cts`

This is also the file whose `check` flag causes the 35-second fsck; see
`patches/patch-skip-data-fsck-fox_12.1.diff`.

## Versions

| property | value |
|---|---|
| `ro.build.version.release` (system) | 14 |
| `ro.build.version.sdk` | 34 |
| `ro.vendor.build.version.release` | 12 |
| `ro.board.first_api_level` | 31 |
| `ro.vendor.api_level` | 31 |
| `ro.product.first_api_level` | 34 |
| `ro.vendor.build.security_patch` | 2025-04-05 |

Note the split: system is Android 14, vendor is frozen at Android 12. The
security HALs live on the vendor side, so they are the same across firmware
variants unless the vendor image itself was rebuilt.

## How to collect the same set from another firmware

No root needed, from a booted system (Termux or `adb shell`):

```sh
getprop ro.hardware.gatekeeper
grep -A2 -iE "keymaster|keymint|gatekeeper" /vendor/etc/vintf/manifest.xml
cat /vendor/etc/vintf/manifest/*.xml 2>/dev/null | grep -A2 -iE "keymint|keymaster"
grep userdata /vendor/etc/fstab.mt6789
getprop ro.build.version.release; getprop ro.vendor.build.version.release
```

## Reading the diff

| what differs | what it means |
|---|---|
| nothing | recovery needs no change; it reads all of this from the device at runtime |
| gatekeeper or keymint version | set `OF_DEFAULT_KEYMASTER_VERSION` in `vendorsetup.sh` |
| `fileencryption=` or `keydirectory=` | fstab change, common tree |
| system Android version | spblob format may differ — deeper, needs a recovery.log |
