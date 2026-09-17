# Decryption config: IN firmware v7 vs NEEA

A user on Indonesian firmware v7 reports that PIN unlock fails in the recovery,
while decryption with the default password still works. No logs were available.
This compares the IN v7 vendor/system configuration against the NEEA firmware
this tree was built against, to find out whether anything the recovery's
decryption path depends on actually changed.

**Verdict: nothing in the crypto configuration differs.** The cause is not a HAL
version, not the FBE policy and not the key directory, so none of those are worth
patching. What remains is the credential path on the system side, and that needs
a `recovery.log` from an affected device to go further.

Sources: IN v7 dump of `/system/build.prop`, `/vendor/build.prop`,
`/vendor/etc/vintf/*`, `/vendor/etc/fstab.mt6789`; NEEA side from the live device
and from `fstab.mt6789` in the common tree.

## Identical between IN v7 and NEEA

Security HALs, all implemented by **trustkernel**:

| HAL | format | version |
|---|---|---|
| `android.hardware.gatekeeper` | HIDL | 1.0 |
| `android.hardware.security.keymint` | AIDL | 1 (no version attribute) |
| `android.hardware.security.secureclock` | AIDL | 1 |
| `android.hardware.security.sharedsecret` | AIDL | 1 |
| `vendor.mediatek.hardware.keymaster_attestation` | HIDL | 1.1 |

/data encryption, from the fstab `/data` line:

- `fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized`
- `keydirectory=/metadata/vold/metadata_encryption`
- `inlinecrypt`, `checkpoint=fs`
- `ro.crypto.volume.filenames_mode=aes-256-cts`
- `ro.hardware.gatekeeper=trustkernel`

Vendor side generally:

- `ro.vendor.build.version.release=12` (vendor is frozen at Android 12 on both)
- `ro.vendor.build.security_patch=2025-04-05`
- `ro.board.first_api_level=31`, `ro.product.first_api_level=34`
- system is Android 14 / SDK 34 on both

The security HALs live in vendor, and vendor did not move. That is why the
recovery needs no change for IN: it reads the fstab, the HALs and the vendor
libraries off the device at runtime.

## What IN v7 did change

None of these touch decryption, but they are the real differences:

| | NEEA (tree) | IN v7 |
|---|---|---|
| erofs alternatives for system/vendor/product/dlkm | present | removed, ext4 only |
| AVB | no explicit flags | `avb=vbmeta_system` on system/system_ext, `avb` on vendor/product/dlkm, `avb=vbmeta` on vbmeta_system |
| `/data` mount options | `sysfs_path=/sys/devices/platform/soc/11270000.ufshci` | removed |
| `/data` mount options | `resgid=1065,,inlinecrypt` (stray double comma) | `resgid=1065,inlinecrypt` |
| usbotg | `voldmanaged=usbotg:auto,encryptable=userdata` | `voldmanaged=usbotg:auto` |
| system security patch | 2025-08-05 | 2026-09-05 |

## Still needed to diagnose the PIN failure

From an affected IN device, entering the PIN in recovery and letting it fail:

```
adb pull /tmp/recovery.log
```

The log names the keymaster version the recovery picked, whether the spblob was
read, and which step returned the failure — the part this comparison cannot
reach.

## Collecting this set elsewhere

No root needed, from a booted system (Termux or `adb shell`):

```sh
getprop ro.hardware.gatekeeper
grep -A2 -iE "keymaster|keymint|gatekeeper" /vendor/etc/vintf/manifest.xml
cat /vendor/etc/vintf/manifest/*.xml 2>/dev/null | grep -A2 -iE "keymint|keymaster"
grep userdata /vendor/etc/fstab.mt6789
getprop ro.build.version.release; getprop ro.vendor.build.version.release
```

## Outcome: the reported failure is a credential mismatch, not a bug

Logs from both devices settle it. Reproducing a **wrong** PIN on a healthy
NEEA device produces exactly the reported failure, line for line:

```
Attempting to decrypt user's synthetic password
fscrypt::GetPassword_Token
Is_Weaver
using secdis to decrypt spblob
Attempting to unwrap synthetic password blob
spblob v2 / v3
Begin Operation failed
failed to unwrapSyntheticPasswordBlob
Failed to decrypt user 0
```

The correct PIN on the same device, same run, takes the same path and ends in
`User 0 Decrypted Successfully!`. So `Begin Operation failed` is simply what a
rejected credential looks like — keymaster refuses to start the operation with
a key derived from the wrong input.

On the IN device the whole path up to that point succeeds: metadata decrypted,
`/data` mounted, the blob located and identified as `spblob v2 / v3`. Nothing in
the log distinguishes it from the wrong-PIN case.

Ruled out along the way, each by evidence rather than argument:

- **spblob format** — both devices report `spblob v2 / v3` and parse it
- **keymaster version** — `4.1` on both, HALs identical (see above)
- **the patched LK** — both report `device_state=locked`,
  `verifiedbootstate=green`; it is the same on the working device
- **the custom kernel** — the IN device runs `5.10.260-SuiKernel-Stable-KSUN`
  against stock `5.10.205-android12-...` here, but the code path taken is
  identical on both

What remains is on the device itself: the credential material protecting the
blob does not match what is being typed, or its keystore state is inconsistent.
Neither is reachable from the recovery side, and neither is a reason to change
anything in this tree.

If the report resurfaces, the first thing to ask for is a new simple PIN set
from the system, then a fresh attempt — not another build.
