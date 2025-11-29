#!/bin/bash
# gather-config.sh - Collect current system configurations
# Usage: ./gather-config.sh <hostname> <os-type>
#   os-type: debian12 or rhel10

set -euo pipefail

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <hostname> <os-type>"
    echo "  os-type: debian12 or rhel10"
    exit 1
fi

HOSTNAME="$1"
OS_TYPE="$2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/hosts/${OS_TYPE}"

# Validate OS type
if [[ ! "$OS_TYPE" =~ ^(debian12|rhel10)$ ]]; then
    echo "Error: os-type must be 'debian12' or 'rhel10'"
    exit 1
fi

echo "Gathering configurations for ${HOSTNAME} (${OS_TYPE})..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Gather SSH configuration
echo "- Collecting SSH configuration..."
if [ -f /etc/ssh/sshd_config ]; then
    sudo cp /etc/ssh/sshd_config "${OUTPUT_DIR}/sshd_config"
    echo "  ✓ /etc/ssh/sshd_config"
fi

# Gather fstab
echo "- Collecting filesystem mounts..."
if [ -f /etc/fstab ]; then
    cp /etc/fstab "${OUTPUT_DIR}/fstab"
    echo "  ✓ /etc/fstab"
fi

# Gather sysctl configuration
echo "- Collecting kernel parameters..."
if [ -f /etc/sysctl.conf ]; then
    cp /etc/sysctl.conf "${OUTPUT_DIR}/sysctl.conf"
    echo "  ✓ /etc/sysctl.conf"
fi

# OS-specific network configuration
if [ "$OS_TYPE" == "debian12" ]; then
    echo "- Collecting Debian network configuration..."
    
    # ifupdown (traditional)
    if [ -f /etc/network/interfaces ]; then
        cp /etc/network/interfaces "${OUTPUT_DIR}/interfaces"
        echo "  ✓ /etc/network/interfaces"
    fi
    
    # systemd-networkd
    if [ -d /etc/systemd/network ]; then
        mkdir -p "${OUTPUT_DIR}/systemd-networkd"
        if compgen -G "/etc/systemd/network/*.network" > /dev/null; then
            cp /etc/systemd/network/*.network "${OUTPUT_DIR}/systemd-networkd/" 2>/dev/null || true
            echo "  ✓ /etc/systemd/network/*.network"
        fi
    fi
    
    # Netplan (if used)
    if [ -d /etc/netplan ]; then
        mkdir -p "${OUTPUT_DIR}/netplan"
        if compgen -G "/etc/netplan/*.yaml" > /dev/null; then
            cp /etc/netplan/*.yaml "${OUTPUT_DIR}/netplan/" 2>/dev/null || true
            echo "  ✓ /etc/netplan/*.yaml"
        fi
    fi

elif [ "$OS_TYPE" == "rhel10" ]; then
    echo "- Collecting RHEL network configuration..."
    
    # NetworkManager connection files
    if [ -d /etc/NetworkManager/system-connections ]; then
        mkdir -p "${OUTPUT_DIR}/NetworkManager"
        if compgen -G "/etc/NetworkManager/system-connections/*.nmconnection" > /dev/null; then
            sudo cp /etc/NetworkManager/system-connections/*.nmconnection "${OUTPUT_DIR}/NetworkManager/" 2>/dev/null || true
            echo "  ✓ /etc/NetworkManager/system-connections/*.nmconnection"
        fi
    fi
    
    # Legacy network scripts (if present)
    if [ -d /etc/sysconfig/network-scripts ]; then
        if compgen -G "/etc/sysconfig/network-scripts/ifcfg-*" > /dev/null; then
            cp /etc/sysconfig/network-scripts/ifcfg-* "${OUTPUT_DIR}/" 2>/dev/null || true
            echo "  ✓ /etc/sysconfig/network-scripts/ifcfg-*"
        fi
    fi
fi

# Gather chrony/NTP configuration
echo "- Collecting time synchronization configuration..."
if [ -f /etc/chrony.conf ]; then
    cp /etc/chrony.conf "${OUTPUT_DIR}/chrony.conf"
    echo "  ✓ /etc/chrony.conf"
elif [ -f /etc/chrony/chrony.conf ]; then
    cp /etc/chrony/chrony.conf "${OUTPUT_DIR}/chrony.conf"
    echo "  ✓ /etc/chrony/chrony.conf"
elif [ -f /etc/ntp.conf ]; then
    cp /etc/ntp.conf "${OUTPUT_DIR}/ntp.conf"
    echo "  ✓ /etc/ntp.conf"
fi

# Gather systemd services (custom units only)
echo "- Collecting custom systemd units..."
if [ -d /etc/systemd/system ]; then
    mkdir -p "${OUTPUT_DIR}/systemd"
    find /etc/systemd/system -maxdepth 1 -name "*.service" -type f -exec cp {} "${OUTPUT_DIR}/systemd/" \; 2>/dev/null || true
    if [ -n "$(ls -A ${OUTPUT_DIR}/systemd 2>/dev/null)" ]; then
        echo "  ✓ Custom systemd units"
    fi
fi

# Create metadata file
echo "- Creating metadata..."
cat > "${OUTPUT_DIR}/.metadata.json" <<EOF
{
  "hostname": "${HOSTNAME}",
  "os_type": "${OS_TYPE}",
  "collected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "collected_by": "${USER}",
  "kernel": "$(uname -r)",
  "os_release": "$(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
}
EOF

echo ""
echo "✓ Configuration collection complete!"
echo "  Output directory: ${OUTPUT_DIR}"
echo ""
echo "Next steps:"
echo "  1. Review collected files for sensitive data"
echo "  2. Sanitize any passwords, keys, or private information"
echo "  3. Add to git: git add hosts/${OS_TYPE}/"
echo "  4. Commit: git commit -m 'Add configuration for ${HOSTNAME}'"
echo "  5. Push: git push"
