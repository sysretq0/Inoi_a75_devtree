#!/sbin/sh

# Clone Trustkernel Device Keys for Decryption purposes
mkdir -p /mnt/vendor/persist/t6_rec /mnt/vendor/protect_f/tee_rec

if [ -d /mnt/vendor/persist/t6 ]; then
    cp -af /mnt/vendor/persist/t6/* /mnt/vendor/persist/t6_rec/ 2>/dev/null
    chown -R system:system /mnt/vendor/persist/t6_rec
    chmod -R 0700 /mnt/vendor/persist/t6_rec
fi

if [ -d /mnt/vendor/protect_f/tee ]; then
    cp -af /mnt/vendor/protect_f/tee/* /mnt/vendor/protect_f/tee_rec/ 2>/dev/null
    chown -R system:system /mnt/vendor/protect_f/tee_rec
    chmod -R 0700 /mnt/vendor/protect_f/tee_rec
fi
