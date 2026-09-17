#!/bin/bash
# Slim OrangeFox theme: remove unused fonts and all languages except en/ru.
# Usage: apply-patches.sh <fox_source_root>   (e.g. .../workspace/fox_12.1)
# Runs after source sync, before build. Deletes files only - never touches
# ui.xml or theme structure (theme version mismatch => GUI bootloop).
set -e
FOX="$1"
if [ -z "$FOX" ] || [ ! -d "$FOX/bootable/recovery/gui" ]; then
    echo "ERROR: pass fox source root as arg1 (got: '$FOX')"
    exit 1
fi
GUI="$FOX/bootable/recovery/gui"
PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- 0. Fix DT2W wake-from-blanked-screen bug in gui.cpp ---
# Upstream InputHandler::processInput() only calls resetTimerAndUnblank()
# while the screen is NOT already off, so a KEY_WAKEUP event from a
# double-tap-to-wake gesture driver can never turn the screen back on.
# This patch adds an explicit exception for KEY_WAKEUP while blanked.
GUI_WAKE_PATCH="$PATCH_DIR/patch-gui-keywakeup-fox_12.1.diff"
echo "=== Applying KEY_WAKEUP unblank fix ==="
if [ ! -f "$GUI_WAKE_PATCH" ]; then
    echo "WARNING: $GUI_WAKE_PATCH not found, skipping KEY_WAKEUP fix"
elif patch -p1 --dry-run -d "$FOX/bootable/recovery" < "$GUI_WAKE_PATCH" > /dev/null 2>&1; then
    patch -p1 -d "$FOX/bootable/recovery" < "$GUI_WAKE_PATCH"
    echo "KEY_WAKEUP patch applied successfully"
else
    echo "WARNING: KEY_WAKEUP patch failed dry-run (gui.cpp upstream context may have changed) - skipping, build continues"
fi

# --- 0b. DT2S: double-tap on the status bar blanks the screen ---
# Adds double-tap detection (40-400 ms window) in InputHandler::doTouchStart()
# for the top 5% of the framebuffer (status bar zone). Blanks via the same
# blankTimer.toggleBlank() used by the screen timeout; wake-up is handled by
# the KEY_WAKEUP (DT2W) patch above.
GUI_DT2S_PATCH="$PATCH_DIR/patch-gui-dt2s-statusbar-fox_12.1.diff"
echo "=== Applying DT2S status bar blank ==="
if [ ! -f "$GUI_DT2S_PATCH" ]; then
    echo "WARNING: $GUI_DT2S_PATCH not found, skipping DT2S"
elif patch -p1 --dry-run -d "$FOX/bootable/recovery" < "$GUI_DT2S_PATCH" > /dev/null 2>&1; then
    patch -p1 -d "$FOX/bootable/recovery" < "$GUI_DT2S_PATCH"
    echo "DT2S patch applied successfully"
else
    echo "WARNING: DT2S patch failed dry-run (gui.cpp upstream context may have changed) - skipping, build continues"
fi

# --- 0c. Cache Get_Folder_Size() results in TWPartition::Update_Size() ---
# Update_System_Details() is called 14+ times per recovery boot; each call
# triggers full recursive walks of /data (~256 app dirs) and /storage,
# costing ~30s each on real user devices. Log shows three consecutive
# "Data backup size is ..." with identical result, hence the 3x slowdown
# vs TWRP. Cache is a per-session static; wipe/restore reset partition
# state via other code paths and don't rely on this recompute.
GUI_UPDSIZE_PATCH="$PATCH_DIR/patch-partition-update_size-cache-fox_12.1.diff"
echo "=== Applying Update_Size() cache ==="
if [ ! -f "$GUI_UPDSIZE_PATCH" ]; then
    echo "WARNING: $GUI_UPDSIZE_PATCH not found, skipping Update_Size cache"
elif patch -p1 --dry-run -d "$FOX/bootable/recovery" < "$GUI_UPDSIZE_PATCH" > /dev/null 2>&1; then
    patch -p1 -d "$FOX/bootable/recovery" < "$GUI_UPDSIZE_PATCH"
    echo "Update_Size cache patch applied successfully"
else
    echo "WARNING: Update_Size cache patch failed dry-run (partition.cpp upstream context may have changed) - skipping, build continues"
fi

# --- 0d. Board backup exclusions for every partition + internal self-backup ---
# TW_BACKUP_EXCLUSIONS is only read in Setup_Data_Media(), which runs for /data
# alone, and /data already excludes /data/media wholesale - so the board list
# never reached the /storage mount point and had no effect at all. This moves
# the list into Partition_Post_Processing(), which runs for every partition.
# It also gates the "cannot backup Internal Storage onto itself" abort behind
# TW_ALLOW_INTERNAL_SELF_BACKUP, so the board can opt in once the destination
# folder is covered by the exclusions.
BACKUP_EXCL_PATCH="$PATCH_DIR/patch-backup-exclusions-internal-fox_12.1.diff"
echo "=== Applying backup exclusions / internal self-backup ==="
if [ ! -f "$BACKUP_EXCL_PATCH" ]; then
    echo "WARNING: $BACKUP_EXCL_PATCH not found, skipping backup exclusions fix"
elif patch -p1 --dry-run -d "$FOX/bootable/recovery" < "$BACKUP_EXCL_PATCH" > /dev/null 2>&1; then
    patch -p1 -d "$FOX/bootable/recovery" < "$BACKUP_EXCL_PATCH"
    echo "Backup exclusions patch applied successfully"
else
    echo "WARNING: backup exclusions patch failed dry-run (partition.cpp/partitionmanager.cpp/Android.mk upstream context may have changed) - skipping, build continues"
fi

# --- 0e. Cap the persistent recovery log ---
# TWFunc::Copy_Log() appends each boot's log to the full contents of the
# previous one and recompresses the lot, with no upper bound. On this device
# /data/recovery/log.gz had reached 66 MB compressed (~1 GB of text), and
# Update_Log_File() - which calls it, twice per boot - spent 11.5 s per call.
# Deleting the file dropped startup from 65.4 s to 42.3 s; this patch keeps it
# from growing back, starting a fresh log past a 1 MB cap. last_log.gz still
# holds the previous contents.
# Disable by renaming this .diff to .diff.bak.
LOG_CAP_PATCH="$PATCH_DIR/patch-cap-persistent-log-fox_12.1.diff"
echo "=== Applying persistent log cap ==="
if [ ! -f "$LOG_CAP_PATCH" ]; then
    echo "WARNING: $LOG_CAP_PATCH not found, skipping log cap"
elif patch -p1 --dry-run -d "$FOX/bootable/recovery" < "$LOG_CAP_PATCH" > /dev/null 2>&1; then
    patch -p1 -d "$FOX/bootable/recovery" < "$LOG_CAP_PATCH"
    echo "Persistent log cap applied successfully"
else
    echo "WARNING: log cap patch failed dry-run (twrp-functions.cpp upstream context may have changed) - skipping, build continues"
fi

# --- 0f. Skip the fs_mgr fsck of /data on every recovery entry ---
# The ROM's own fstab (/vendor/etc/fstab.mt6789 here) is copied to
# /etc/additional.fstab and handed to vold for the metadata-encrypted mount.
# It carries the fs_mgr "check" flag on /data, so fs_mgr runs fsck.f2fs first.
# Android never leaves /data with a clean-unmount marker when rebooting into
# recovery, so this fires on every entry from a booted system: measured at
# 34.8 s (ro.boottime.init.fsck.data=34839), reporting the filesystem clean on
# every count. From recovery to recovery, where the unmount is clean, the same
# check costs 48 ms. The patch strips the flag from our private copy only;
# the ROM's fstab is untouched.
# Disable by renaming this .diff to .diff.bak - the gate below then skips it.
DATA_FSCK_PATCH="$PATCH_DIR/patch-skip-data-fsck-fox_12.1.diff"
echo "=== Applying /data fsck skip ==="
if [ ! -f "$DATA_FSCK_PATCH" ]; then
    echo "WARNING: $DATA_FSCK_PATCH not found, skipping /data fsck patch"
elif patch -p1 --dry-run -d "$FOX/bootable/recovery" < "$DATA_FSCK_PATCH" > /dev/null 2>&1; then
    patch -p1 -d "$FOX/bootable/recovery" < "$DATA_FSCK_PATCH"
    echo "/data fsck skip applied successfully"
else
    echo "WARNING: /data fsck patch failed dry-run (partitionmanager.cpp upstream context may have changed) - skipping, build continues"
fi

# --- 0g. Boot-phase timing instrumentation (twrp.cpp) ---
# Pure logging, zero functional change: adds Fox_Log_Boot_Timing(), which
# prints /proc/uptime with a phase tag, at the checkpoints main() and
# process_recovery_mode() already pass through (fstab, gui_init,
# gui_loadResources, Decrypt_Page, Fixup_Time_On_Boot, and the
# reapply_settings-vs-gui_start branch). Existing code paths and return
# values are untouched. Read the result with:
#   grep BOOT_TIMING /tmp/recovery.log
BOOT_TIMING_PATCH="$PATCH_DIR/patch-boot-timing-fox_12.1.diff"
echo "=== Applying boot-timing instrumentation ==="
if [ ! -f "$BOOT_TIMING_PATCH" ]; then
    echo "WARNING: $BOOT_TIMING_PATCH not found, skipping boot-timing instrumentation"
elif patch -p1 --dry-run -d "$FOX/bootable/recovery" < "$BOOT_TIMING_PATCH" > /dev/null 2>&1; then
    patch -p1 -d "$FOX/bootable/recovery" < "$BOOT_TIMING_PATCH"
    echo "Boot-timing instrumentation applied successfully"
else
    echo "WARNING: boot-timing patch failed dry-run (twrp.cpp upstream context may have changed) - skipping, build continues"
fi

# --- 0h. Gatekeeper diagnostics (system/vold, NOT bootable/recovery) ---
# The FBE/spblob credential path calls gatekeeper->verify() and only acts on a
# plain accept: a rejected credential, a lockout, or a keystore that refuses the
# auth token all leave the lambda silently, no token is delivered, and the
# failure only surfaces later in unwrapSyntheticPasswordBlob() as a bare
# "Begin Operation failed" - the exact line a wrong PIN produces. A correct PIN
# entered while gatekeeper is throttling is therefore indistinguishable from a
# wrong one. The other verify() call in the same file, on the FDE path, does
# handle ERROR_RETRY_TIMEOUT, so this is an omission rather than a design.
# Logging only: no control flow changes, every branch still falls through
# exactly as before.
# Note the different -d: this patch applies to system/vold.
# Disable by renaming this .diff to .diff.bak.
GK_DIAG_PATCH="$PATCH_DIR/patch-gatekeeper-diagnostics-fox_12.1.diff"
echo "=== Applying gatekeeper diagnostics ==="
if [ ! -f "$GK_DIAG_PATCH" ]; then
    echo "WARNING: $GK_DIAG_PATCH not found, skipping gatekeeper diagnostics"
elif [ ! -d "$FOX/system/vold" ]; then
    echo "WARNING: $FOX/system/vold not present - skipping gatekeeper diagnostics"
elif patch -p1 --dry-run -d "$FOX/system/vold" < "$GK_DIAG_PATCH" > /dev/null 2>&1; then
    patch -p1 -d "$FOX/system/vold" < "$GK_DIAG_PATCH"
    echo "Gatekeeper diagnostics applied successfully"
else
    echo "WARNING: gatekeeper diagnostics failed dry-run (Decrypt.cpp upstream context may have changed) - skipping, build continues"
fi

echo "=== Theme slimming: start ==="
echo "GUI dir size before:"
du -sh "$GUI"

# --- 1. Fonts: delete-list (verified unused, 0 references in theme XML) ---
# Roboto* and GoogleSans* are BOTH required (different UI layers) - never touch.
# NOTE: FiraCode-Medium is NOT dead despite 0 static refs in theme XML:
# the font picker writes /sdcard/Fox/.theme/font.xml referencing <Name>-Medium.ttf
# dynamically; deleting it bootloops the GUI if the user ever picks FiraCode.
DEAD_FONTS="DroidSansFallback.ttf NotoSansCJKjp-Regular.ttf Chococooky.ttf ae_Cortoba.ttf Roboto-Spanish.ttf"
for f in $DEAD_FONTS; do
    found=$(find "$GUI" -type f -name "$f")
    if [ -n "$found" ]; then
        echo "$found" | while read -r p; do
            echo "DEL font: $p ($(stat -c%s "$p") bytes)"
            rm -f "$p"
        done
    else
        echo "skip (not found): $f"
    fi
done

# --- 2. Languages: keep-list (en + ru), delete the rest ---
KEEP="en.xml ru.xml"
find "$GUI" -type d -name "languages" | while read -r d; do
    echo "languages dir: $d"
    for x in "$d"/*.xml; do
        [ -e "$x" ] || continue
        base=$(basename "$x")
        keep=0
        for k in $KEEP; do
            if [ "$base" = "$k" ]; then keep=1; fi
        done
        if [ "$keep" = "1" ]; then
            echo "KEEP lang: $x"
        else
            echo "DEL  lang: $x ($(stat -c%s "$x") bytes)"
            rm -f "$x"
        fi
    done
done

# --- 3. Sanity: en.xml must survive somewhere, warn if ru.xml absent ---
if [ -z "$(find "$GUI" -path '*languages*' -name 'en.xml')" ]; then
    echo "ERROR: en.xml missing after cleanup - aborting build"
    exit 1
fi
if [ -z "$(find "$GUI" -path '*languages*' -name 'ru.xml')" ]; then
    echo "WARNING: ru.xml not found in source theme - build will be English-only"
fi

echo "GUI dir size after:"
du -sh "$GUI"
echo "=== Theme slimming: done ==="
