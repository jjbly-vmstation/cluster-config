#!/bin/bash
# check-drift.sh - Detect configuration drift between live system and repository
# Usage: ./check-drift.sh <os-type>
#   os-type: debian12 or rhel10

set -euo pipefail

# Check arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <os-type>"
    echo "  os-type: debian12 or rhel10"
    exit 1
fi

OS_TYPE="$1"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${REPO_ROOT}/hosts/${OS_TYPE}"
DRIFT_DETECTED=0

# Validate OS type
if [[ ! "$OS_TYPE" =~ ^(debian12|rhel10)$ ]]; then
    echo "Error: os-type must be 'debian12' or 'rhel10'"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking configuration drift for ${OS_TYPE}..."
echo ""

# Function to compare files
compare_file() {
    local repo_file="$1"
    local system_file="$2"
    local label="$3"
    
    if [ ! -f "$repo_file" ]; then
        echo -e "${YELLOW}⚠${NC}  ${label}: Not tracked in repository"
        return 0
    fi
    
    if [ ! -f "$system_file" ]; then
        echo -e "${RED}✗${NC}  ${label}: Missing on system"
        DRIFT_DETECTED=1
        return 1
    fi
    
    if diff -q "$repo_file" "$system_file" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}  ${label}: No drift"
        return 0
    else
        echo -e "${RED}✗${NC}  ${label}: DRIFT DETECTED"
        DRIFT_DETECTED=1
        echo "    Differences:"
        diff -u "$repo_file" "$system_file" | head -20 | sed 's/^/    /'
        echo ""
        return 1
    fi
}

# Check SSH configuration
compare_file "${CONFIG_DIR}/sshd_config" "/etc/ssh/sshd_config" "SSH configuration"

# Check fstab
compare_file "${CONFIG_DIR}/fstab" "/etc/fstab" "Filesystem mounts"

# Check sysctl
if [ -f "${CONFIG_DIR}/sysctl.conf" ]; then
    compare_file "${CONFIG_DIR}/sysctl.conf" "/etc/sysctl.conf" "Kernel parameters"
fi

# Check time synchronization
if [ -f "${CONFIG_DIR}/chrony.conf" ]; then
    if [ -f /etc/chrony.conf ]; then
        compare_file "${CONFIG_DIR}/chrony.conf" "/etc/chrony.conf" "Chrony configuration"
    elif [ -f /etc/chrony/chrony.conf ]; then
        compare_file "${CONFIG_DIR}/chrony.conf" "/etc/chrony/chrony.conf" "Chrony configuration"
    fi
elif [ -f "${CONFIG_DIR}/ntp.conf" ]; then
    compare_file "${CONFIG_DIR}/ntp.conf" "/etc/ntp.conf" "NTP configuration"
fi

# OS-specific network configuration checks
if [ "$OS_TYPE" == "debian12" ]; then
    echo ""
    echo "Checking Debian network configuration..."
    
    # ifupdown
    if [ -f "${CONFIG_DIR}/interfaces" ]; then
        compare_file "${CONFIG_DIR}/interfaces" "/etc/network/interfaces" "Network interfaces (ifupdown)"
    fi
    
    # systemd-networkd
    if [ -d "${CONFIG_DIR}/systemd-networkd" ]; then
        for net_file in "${CONFIG_DIR}/systemd-networkd"/*.network; do
            if [ -f "$net_file" ]; then
                basename=$(basename "$net_file")
                compare_file "$net_file" "/etc/systemd/network/$basename" "systemd-networkd: $basename"
            fi
        done
    fi
    
    # Netplan
    if [ -d "${CONFIG_DIR}/netplan" ]; then
        for netplan_file in "${CONFIG_DIR}/netplan"/*.yaml; do
            if [ -f "$netplan_file" ]; then
                basename=$(basename "$netplan_file")
                compare_file "$netplan_file" "/etc/netplan/$basename" "Netplan: $basename"
            fi
        done
    fi

elif [ "$OS_TYPE" == "rhel10" ]; then
    echo ""
    echo "Checking RHEL network configuration..."
    
    # NetworkManager
    if [ -d "${CONFIG_DIR}/NetworkManager" ]; then
        for nm_file in "${CONFIG_DIR}/NetworkManager"/*.nmconnection; do
            if [ -f "$nm_file" ]; then
                basename=$(basename "$nm_file")
                if [ -f "/etc/NetworkManager/system-connections/$basename" ]; then
                    # Note: requires sudo for NetworkManager files
                    if sudo diff -q "$nm_file" "/etc/NetworkManager/system-connections/$basename" > /dev/null 2>&1; then
                        echo -e "${GREEN}✓${NC}  NetworkManager: $basename: No drift"
                    else
                        echo -e "${RED}✗${NC}  NetworkManager: $basename: DRIFT DETECTED"
                        DRIFT_DETECTED=1
                    fi
                else
                    echo -e "${RED}✗${NC}  NetworkManager: $basename: Missing on system"
                    DRIFT_DETECTED=1
                fi
            fi
        done
    fi
    
    # Legacy network scripts
    for ifcfg_file in "${CONFIG_DIR}"/ifcfg-*; do
        if [ -f "$ifcfg_file" ]; then
            basename=$(basename "$ifcfg_file")
            compare_file "$ifcfg_file" "/etc/sysconfig/network-scripts/$basename" "Network script: $basename"
        fi
    done
fi

# Summary
echo ""
echo "================================"
if [ $DRIFT_DETECTED -eq 0 ]; then
    echo -e "${GREEN}✓ No drift detected${NC}"
    echo "All tracked configurations match the repository."
    exit 0
else
    echo -e "${RED}✗ Drift detected${NC}"
    echo "Some configurations have diverged from the repository."
    echo ""
    echo "Actions:"
    echo "  1. Review the differences above"
    echo "  2. If changes are intentional, update the repository:"
    echo "     ./scripts/gather-config.sh <hostname> ${OS_TYPE}"
    echo "  3. If changes are unwanted, re-apply configurations:"
    echo "     ansible-playbook -i /srv/vmstation-org/cluster-setup/ansible/inventory/hosts.yml playbooks/apply-config.yml"
    exit 1
fi
