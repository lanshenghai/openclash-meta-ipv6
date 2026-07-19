#!/bin/sh
# Patch OpenClash custom overwrite script to set TUN MTU.
# OpenClash does not expose tun.mtu in UCI; inject via ruby_edit after config merge.
# Usage on router: sh patch-tun-mtu.sh [mtu]
# Default MTU: 1400 (PPPoE + TUN overhead; was 9000 by default)

MTU="${1:-1400}"
TARGET=/etc/openclash/custom/openclash_custom_overwrite.sh

if [ ! -f "$TARGET" ]; then
  echo "missing $TARGET"
  exit 1
fi

if grep -q "tun.*mtu" "$TARGET" 2>/dev/null; then
  sed -i "s/ruby_edit \"\$CONFIG_FILE\" \"\['tun'\]\['mtu'\]\" \"[0-9]*\"/ruby_edit \"\$CONFIG_FILE\" \"['tun']['mtu']\" \"$MTU\"/" "$TARGET"
  echo "updated mtu=$MTU"
  exit 0
fi

head -n -1 "$TARGET" > /tmp/oc_overwrite.sh
cat >> /tmp/oc_overwrite.sh << EOF
ruby_edit "\$CONFIG_FILE" "['tun']['mtu']" "$MTU"

exit 0
EOF
mv /tmp/oc_overwrite.sh "$TARGET"
chmod +x "$TARGET"
echo "patched mtu=$MTU"
tail -4 "$TARGET"
