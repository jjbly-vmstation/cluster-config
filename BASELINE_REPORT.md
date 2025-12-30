# VMStation Cluster Baseline Configuration Report

**Generated**: 2025-11-29T16:50:39Z  
**Cluster**: VMStation Production  
**Total Hosts**: 3

---

## Executive Summary

This report documents the baseline configuration state of all VMStation cluster machines. All critical system configurations have been captured and version-controlled to prevent drift and ensure operational stability.

## Cluster Topology

### Control Plane
- **masternode** (192.168.4.63)
  - Role: Kubernetes control plane + monitoring
  - OS: Debian GNU/Linux 12.10 (bookworm)
  - Kernel: 6.1.0-32-amd64
  - WOL MAC: 00:e0:4c:68:cb:bf

### Worker Nodes
- **storagenodet3500** (192.168.4.61)
  - Role: Storage node with media services
  - OS: Debian GNU/Linux 12.10 (bookworm)
  - WOL MAC: b8:ac:6f:7e:6c:9d

- **homelab** (192.168.4.62)
  - Role: General workload compute node
  - OS: Red Hat Enterprise Linux 10.0 (Coughlan)
  - WOL MAC: d0:94:66:30:d6:63
  - Note: Uses non-root user with passwordless sudo
- **iDRAC** (192.168.4.60)
  - Role: iDRAC controller for homelab node
  - OS: iDRAC 8
  - WOL MAC: d0:94:66:30:d6:67
---

## Configuration Coverage

### ✓ All Hosts - Captured Configurations

#### SSH Configuration
- **Location**: `hosts/<hostname>/sshd_config`
- **Status**: ✓ Collected from all 3 hosts
- **Critical Settings**:
  - Authentication methods
  - Port and security settings
  - Key-based access configuration

#### Filesystem Mounts
- **Location**: `hosts/<hostname>/fstab`
- **Status**: ✓ Collected from all 3 hosts
- **Contains**:
  - Root and boot partitions
  - Persistent mount points
  - Mount options and UUIDs

#### Kernel Parameters
- **Location**: `hosts/<hostname>/sysctl.conf`
- **Status**: ✓ Collected from all 3 hosts
- **Settings**:
  - Network tuning
  - Memory management
  - Security parameters

#### Time Synchronization
- **Location**: `hosts/<hostname>/chrony.conf`
- **Status**: ✓ Collected from all 3 hosts
- **Type**: Chrony (all hosts)
- **Critical**: Ensures time sync across cluster

#### Network Configuration

##### Debian Hosts (masternode, storagenodet3500)
- **Method**: Traditional ifupdown
- **Location**: `hosts/<hostname>/interfaces`
- **Status**: ✓ Collected
- **Contains**: Static IP configuration

##### RHEL Host (homelab)
- **Method**: NetworkManager
- **Location**: `hosts/homelab/NetworkManager/*.nmconnection`
- **Status**: ✓ Collected (4 connection files)
- **Interfaces**:
  - `static-eno1.nmconnection` - Primary interface with static IP
  - `eno2.nmconnection`
  - `eno3.nmconnection`
  - `eno4.nmconnection`

#### Hostname and Hosts Files
- **Status**: ✓ Collected from all 3 hosts
- **Purpose**: DNS resolution and hostname mapping

#### Custom Systemd Units

##### masternode
- `containerd.service` - Container runtime
- `kubelet.service` - Kubernetes node agent
- `etcd.service` - Kubernetes datastore
- `loki.service` - Log aggregation
- `node_exporter.service` - Prometheus metrics
- `podman-metrics.service` - Podman monitoring
- `podman-stats-forwarder.service` - Stats collection
- `vmstation-autosleep.service` - Power management
- `vmstation-idle-check.service` - Idle detection

##### storagenodet3500
- `containerd.service` - Container runtime
- `kubelet.service` - Kubernetes node agent
- `cloudflared.service` - Cloudflare tunnel
- `cloudflared-update.service` - Tunnel updater
- `node_exporter.service` - Prometheus metrics
- `podman-metrics.service` - Podman monitoring
- `podman-stats-forwarder.service` - Stats collection
- `vmstation-autosleep.service` - Power management

##### homelab
- `containerd.service` - Container runtime
- `kubelet.service` - Kubernetes node agent
- `node_exporter.service` - Prometheus metrics
- `podman-metrics.service` - Podman monitoring
- `podman-stats-forwarder.service` - Stats collection
- `vmstation-autosleep.service` - Power management

---

## Critical Configuration Details

### Network Configuration

#### Static IP Assignments
- **masternode**: 192.168.4.63 (gateway: likely 192.168.4.1)
- **storagenodet3500**: 192.168.4.61
- **homelab**: 192.168.4.62

#### Network Topology
- All nodes on same subnet: 192.168.4.0/24
- Control plane endpoint: 192.168.4.63:6443
- Kubernetes pod network: 10.244.0.0/16
- Kubernetes service network: 10.96.0.0/12

### Storage Configuration

#### masternode
- Root filesystem: Standard Debian partitioning
- Monitoring data storage paths

#### storagenodet3500
- Media storage path: `/srv/media`
- Jellyfin config path: `/var/lib/jellyfin`
- Additional persistent mounts (see fstab)

#### homelab
- Standard RHEL 10 partitioning

### Container Runtime
- **All hosts**: containerd
- **Socket**: unix:///var/run/containerd/containerd.sock
- **Version**: Kubernetes 1.29 compatible

### Monitoring Stack
- **Node Exporter**: Running on all hosts
- **Podman Metrics**: Custom monitoring integration
- **Loki**: Log aggregation on masternode

---

## Security Considerations

### SSH Access
- **masternode**: Direct root access (local connection)
- **storagenodet3500**: SSH key-based root access
- **homelab**: SSH key-based user access with passwordless sudo

### Network Security
- All SSH connections use key-based authentication
- StrictHostKeyChecking disabled in Ansible (lab environment)
- Wake-on-LAN configured for power management

### Secrets Management
⚠️ **Important**: This baseline does NOT include:
- SSH private keys
- TLS certificates
- Kubernetes secrets
- Application passwords
- API tokens

These must be managed separately using secure secrets management.

---

## Operational Notes

### Power Management
- **vmstation-autosleep.service**: Automated sleep/wake on all hosts
- **vmstation-idle-check.service**: Idle detection on masternode
- All hosts support Wake-on-LAN

### Cloudflare Integration
- **storagenodet3500**: Runs Cloudflare tunnel for external access
- Enables secure external connectivity without port forwarding

### High Availability
- Single control plane node (masternode)
- etcd runs locally on control plane
- No HA configured for control plane

---

## Drift Detection Status

### Initial Baseline
✓ All configurations captured successfully on 2025-11-29

### Recommended Monitoring
- Daily drift checks via `playbooks/validate-config.yml`
- Weekly manual reviews of critical configs
- Automated alerts on configuration divergence

### Known Variances
- None (initial baseline)

---

## Validation Checklist

### Pre-Deployment Validation
- [x] SSH configurations captured
- [x] Network configurations captured
- [x] Filesystem mounts documented
- [x] Systemd units inventoried
- [x] Time synchronization verified
- [x] Kernel parameters recorded

### Post-Deployment Testing
- [ ] SSH access functional on all nodes
- [ ] Network connectivity verified
- [ ] All mounts active
- [ ] Systemd services operational
- [ ] Kubernetes cluster healthy
- [ ] Monitoring stack functional

---

## Recovery Procedures

### If Configuration Drift Detected

1. **Identify drift**:
   ```bash
  ansible-playbook -i /srv/vmstation-org/cluster-setup/ansible/inventory/hosts.yml playbooks/validate-config.yml
   # or
   ./scripts/check-drift.sh debian12  # on Debian hosts
   ```

2. **Review changes**:
   ```bash
   # Compare live vs repo
   diff /etc/ssh/sshd_config hosts/<hostname>/sshd_config
   ```

3. **Decide action**:
   - **If change is legitimate**: Update repository
     ```bash
     ./scripts/gather-config.sh <hostname> <os-type>
     git add hosts/<hostname>/
     git commit -m "Update baseline for legitimate change"
     ```
   
   - **If change is unwanted**: Re-apply baseline
     ```bash
    ansible-playbook -i /srv/vmstation-org/cluster-setup/ansible/inventory/hosts.yml playbooks/apply-config.yml --limit <hostname>
     ```

### Emergency Network Recovery

If network configuration breaks connectivity:

1. **Console access required** (IPMI/KVM/Physical)
2. **Restore from backup**:
   ```bash
   # On affected host
   cp /etc/network/interfaces.backup /etc/network/interfaces
   systemctl restart networking
   ```
3. **Or manually restore known-good config from this repo**

### SSH Access Recovery

If SSH configuration breaks access:

1. **Use console access**
2. **Restore SSH config**:
   ```bash
   cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
   systemctl restart sshd
   ```

### iDRAC Network Recovery

If the iDRAC (BMC) is unresponsive on the network (cannot ping or access web/SSH):

1. **Check physical connections:**
  - Verify the network cable is securely connected to the iDRAC port and switch.
  - Try a different cable or switch port if possible.
2. **Validate network settings:**
  - If you have console access, confirm iDRAC IP, subnet, and gateway are correct.
3. **Reset the BMC:**
  - Run:
    ```bash
    sudo ipmitool mc reset cold
    ```
  - Wait 2–3 minutes for the BMC to reboot.
  - Monitor recovery with:
    ```bash
    watch -n 5 sudo ipmitool sel list
    ```
  - Retry pinging the iDRAC IP.
4. **Full power cycle (if needed):**
  - Remove AC power from the server, wait 30 seconds, then restore power.
5. **Escalate:**
  - If still unreachable, consult Dell documentation for forced recovery or hardware replacement.

**Note:** During BMC reset, IPMI commands may fail until the controller is back online. Use `watch` to monitor SEL log and BMC recovery status.

### Remote iDRAC Diagnostic Runbook

When diagnosing iDRAC/BMC issues remotely via SSH, capture all relevant diagnostics and logs for offline review:

1. **Capture BMC/iDRAC status and logs to files:**
  ```bash
  sudo ipmitool mc info > idrac_mc_info.txt
  sudo ipmitool lan print > idrac_lan_print.txt
  sudo ipmitool user list > idrac_user_list.txt
  sudo ipmitool chassis status > idrac_chassis_status.txt
  sudo ipmitool sel list > idrac_sel_list.txt
  ```

2. **Monitor SEL log in real time and save output:**
  ```bash
  watch -n 5 'sudo ipmitool sel list > idrac_sel_watch.txt'
  # Or, for a timeline snapshot every minute for 10 minutes:
  for i in {1..10}; do sudo ipmitool sel list >> idrac_sel_timeline.txt; sleep 60; done
  ```

3. **Capture network diagnostics:**
  ```bash
  ping -c 10 192.168.4.60 > idrac_ping.txt
  arp -an | grep 192.168.4.60 > idrac_arp.txt
  ```

4. **If resetting the BMC, capture output:**
  ```bash
  sudo ipmitool mc reset cold > idrac_reset_output.txt 2>&1
  ```

5. **Review or transfer the .txt files for offline analysis.**

This workflow allows full remote diagnosis and log capture for iDRAC/BMC issues without requiring physical presence at the server.
---

## Maintenance Schedule

### Daily
- Automated drift detection (if CI/CD configured)
- Review drift alerts

### Weekly
- Manual configuration review
- Verify backup systems operational

### Monthly
- Full cluster configuration audit
- Update documentation for any intended changes
- Test recovery procedures

### Quarterly
- Review and update baseline
- Security audit of configurations
- Performance tuning review

---

## Related Documentation

- [README.md](README.md) - Main repository documentation
- [QUICK_START.md](QUICK_START.md) - Quick start guide
- [playbooks/gather-baseline.yml](playbooks/gather-baseline.yml) - Baseline gathering playbook
- [playbooks/apply-config.yml](playbooks/apply-config.yml) - Configuration enforcement
- [playbooks/validate-config.yml](playbooks/validate-config.yml) - Drift detection

---

## Appendix A: File Inventory

### masternode
```
hosts/masternode/
├── .metadata.json                 # Host metadata
├── chrony.conf                    # Time sync (345 bytes)
├── fstab                          # Filesystem mounts (1.2K)
├── hostname                       # Hostname file (11 bytes)
├── hosts                          # Hosts file (1.1K)
├── interfaces                     # Network config (428 bytes)
├── sshd_config                    # SSH daemon (3.2K)
├── sysctl.conf                    # Kernel params (2.7K)
└── systemd/                       # Custom systemd units (9 files)
```

### storagenodet3500
```
hosts/storagenodet3500/
├── .metadata.json                 # Host metadata
├── chrony.conf                    # Time sync (271 bytes)
├── fstab                          # Filesystem mounts (1018 bytes)
├── hostname                       # Hostname file (17 bytes)
├── hosts                          # Hosts file (794 bytes)
├── interfaces                     # Network config (418 bytes)
├── sshd_config                    # SSH daemon (3.2K)
├── sysctl.conf                    # Kernel params (2.7K)
└── systemd/                       # Custom systemd units (8 files)
```

### homelab
```
hosts/homelab/
├── .metadata.json                 # Host metadata
├── chrony.conf                    # Time sync (268 bytes)
├── fstab                          # Filesystem mounts (786 bytes)
├── hostname                       # Hostname file (8 bytes)
├── hosts                          # Hosts file (948 bytes)
├── sshd_config                    # SSH daemon (3.7K)
├── sysctl.conf                    # Kernel params (777 bytes)
├── NetworkManager/                # NetworkManager configs (4 files)
└── systemd/                       # Custom systemd units (6 files)
```

---

## Appendix B: Next Steps

1. **Initialize git repository**:
   ```bash
   cd /opt/vmstation_org/machine-config-repo
   git init
   git add .
   git commit -m "Initial baseline configuration for VMStation cluster"
   ```

2. **Push to GitHub**:
   ```bash
   git remote add origin https://github.com/<org>/cluster-config.git
   git branch -M main
   git push -u origin main
   ```

3. **Set up automated drift detection**:
   - Configure GitHub Actions workflow
   - Or set up cron job for daily checks

4. **Document procedures**:
   - Create runbooks for common changes
   - Train team on baseline management
   - Establish change approval process

5. **Test recovery**:
   - Practice restoring configurations
   - Verify backup procedures work
   - Document lessons learned

---

**Report Status**: ✓ Complete  
**Baseline Quality**: Production-ready  
**Recommendation**: Safe to proceed with configuration management
