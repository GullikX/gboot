#!/bin/sh -xe
#
#  gboot
#
#  Copyright 2021 Martin Gulliksson <martin@gullik.cc>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; version 2.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#
#

GBOOT_ROOT="/tmp/gboot-$$"
GBOOT_TARGET_ARCH='x86_64-musl'
GBOOT_REPO='https://alpha.de.repo.voidlinux.org/current/musl'
GBOOT_REPO_KEY='
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>public-key</key>
	<data>LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQ0lqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FnOEFNSUlDQ2dLQ0FnRUF2clN6QlpNdmd2T0NJM0FYYk9qYQoycktSa0pTVE0zYy9FalRJZ0NnRFhndW05M0JQQ3RZOE1jRlZvQ1U0T2lYSEdmVG1xMzlCVk5wTHZMSEw5S2sxCnAyNzhTQmhYVk90YkIyRVZtREtudmZJREVUbGRMR3plN3JaTlJKZHR1TjJtWi9UVnJVQjlTMHlRYytJdWY0aHYKMytEOTdWSWRUSkhBN0FTcjA0MjhwcEVHSkd3U1NoWTJYSm05RDVJMEV1R1JXYzE0TUVHN2RJS0ppWWlNMG5FNAp0WW8yL3ZINElGVEhkblZBM2dZaVp5RG5idUNBUi84RVNmVVRVMTNTTkNPZGJ1ZGYzRDVCY3krVWlNREpJM1llCjRNRktCclQ5WmhaK0dzWEJaWTQ4MmxxaVppNkNMNXB0YzlJUUZmOC9lS1phOGphdGtpVkZWZ3JLZU5Sak9UeE4KZldTdTJua3hHTlgrYmhYWXRoaUdXbUpFWThjQ0FQeUZOK0x2NVJldEsyNTZnZGNiMnNrbUVxZWZ2MnpQQyt3VgpXQmJkSDViRDRiWmpuME42Wmw4MXJ2NVJ6RHZudmYrdkQxNGFGVWJaOFFGcXU3NVBiTDR3Nm1ZTTRsZE0vZzBSCjZOWEU4QXo5Qnd4MnREZlllS3V1dHcxRXBQbTJZdkZ5VFViMWNveUF1VEdSeUFhcDFVVEh2ZzlsaFBJSm1oRlEKSjVrQ2cxcUQ3QTMxV2wwUmxuZTZoZ0dvMFpaTko1Y0pNL3YvelNUS0pjdUZnd283SDBoT0dpbDZEZm84OUI0agpHOTZBQ3lQUytEVktQRlhSWXdqL0FrYkhwYVEyZjFGTUFvU3BCcXVEcUhoM3VrazcxS1g2ajE5dDBpRjhEUUxyCnZ0RlNTZElqREEwMmx3ZVY5TmFRcFdzQ0F3RUFBUT09Ci0tLS0tRU5EIFBVQkxJQyBLRVktLS0tLQo=</data>
	<key>public-key-size</key>
	<integer>4096</integer>
	<key>signature-by</key>
	<string>Void Linux</string>
</dict>
</plist>
'

[ $# -ge 2 ]
overlay="$1"
shift
packages="$@"

[ $(id -u) = 0 ]

workdir="$(realpath .)"

mkdir "$GBOOT_ROOT"
chown root:root "$GBOOT_ROOT"
chmod 755 "$GBOOT_ROOT"

cp "$overlay" "$GBOOT_ROOT/overlay"

mkdir -p "$GBOOT_ROOT/etc/xbps.d" "$GBOOT_ROOT/var/db/xbps/keys"
echo "ignorepkg=linux-base" > "$GBOOT_ROOT/etc/xbps.d/00-ignore-linux-base.conf"
echo "$GBOOT_REPO_KEY" > "$GBOOT_ROOT/var/db/xbps/keys/60:ae:0c:d6:f0:95:17:80:bc:93:46:7a:89:af:a3:2d.plist"

XBPS_TARGET_ARCH="$GBOOT_TARGET_ARCH" xbps-install \
    --rootdir "$GBOOT_ROOT" \
    --repository "$GBOOT_REPO" \
    --sync \
    --unpack-only \
    --yes \
    base-files \
    busybox-static \
    linux-lts \
    xbps-static

XBPS_TARGET_ARCH="$GBOOT_TARGET_ARCH" xbps-install \
    --rootdir "$GBOOT_ROOT" \
    --repository "$GBOOT_REPO" \
    --sync \
    --download-only \
    --yes \
    busybox-static \
    $packages

kernelimage=$(file "$GBOOT_ROOT"/boot/* | grep 'Linux kernel' | cut -d ':' -f 1)
kernelversion=$(basename "$GBOOT_ROOT"/lib/modules/*)
mv "$kernelimage" "$workdir/linux-$kernelversion"

cat <<EOF > "$GBOOT_ROOT/init"
#!/usr/bin/busybox.static sh
busybox.static mkdir /newroot && \
    busybox.static mount -t tmpfs tmpfs /newroot && \
    busybox.static chmod 755 /newroot && \
    xbps-rindex.static -a /var/cache/xbps/*.xbps && \
    xbps-install.static --rootdir /newroot --repository /var/cache/xbps --yes --ignore-file-conflicts busybox-static && \
    xbps-install.static --rootdir /newroot --repository /var/cache/xbps --yes --ignore-file-conflicts $packages && \
    busybox.static mkdir -p /newroot/usr/lib/modules && \
    busybox.static cp -r /usr/lib/modules/$kernelversion /newroot/usr/lib/modules && \
    busybox.static tar -xvf /overlay -C /newroot && \
    busybox.static [ -x /newroot/sbin/init ] && \
    exec busybox.static switch_root /newroot /sbin/init
busybox.static echo "Something went wrong, dropping to shell."
exec busybox.static sh
EOF
chmod +x "$GBOOT_ROOT/init"

(
    cd "$GBOOT_ROOT"
    find . -print0 | cpio --null --create --verbose --format=newc | gzip -9 > "$workdir/initramfs-$kernelversion.cpio.gz"
)

rm -rf "$GBOOT_ROOT"
