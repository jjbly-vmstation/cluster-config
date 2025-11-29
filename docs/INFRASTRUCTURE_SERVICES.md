# Infrastructure Services Documentation

This document describes the core infrastructure services managed by this repository.

## Overview

The VMStation cluster requires several foundational services to operate reliably:

1. **Time Synchronization (NTP/Chrony)** - Ensures consistent time across all nodes
2. **Centralized Logging (Syslog)** - Aggregates logs for monitoring and troubleshooting
3. **Authentication (Kerberos)** - Optional single sign-on capability
4. **Security Hardening** - Baseline security configurations

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    VMStation Cluster                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ masternode  │    │storagenode │    │  homelab    │          │
│  │ (Control)   │    │  (Worker)   │    │  (Worker)   │          │
│  ├─────────────┤    ├─────────────┤    ├─────────────┤          │
│  │ • Chrony    │    │ • Chrony    │    │ • Chrony    │          │
│  │ • RSyslog   │◄───│ • RSyslog   │    │ • RSyslog   │          │
│  │   (server)  │    │   (client)  │    │   (client)  │          │
│  │ • Security  │    │ • Security  │    │ • Security  │          │
│  └─────────────┘    └─────────────┘    └─────────────┘          │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                  │
│                           │                                      │
│                    ┌──────┴───────┐                             │
│                    │ pool.ntp.org │                             │
│                    └──────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

## Service Details

### NTP/Chrony

- **Purpose**: Time synchronization
- **Package**: `chrony`
- **Config**: `/etc/chrony/chrony.conf` (Debian) or `/etc/chrony.conf` (RHEL)
- **Service**: `chrony` (Debian) or `chronyd` (RHEL)

See [TIME_SYNC_SETUP.md](TIME_SYNC_SETUP.md) for detailed configuration.

### Syslog (RSyslog)

- **Purpose**: Centralized log collection
- **Package**: `rsyslog`
- **Config**: `/etc/rsyslog.conf` and `/etc/rsyslog.d/*.conf`
- **Service**: `rsyslog`

See [SYSLOG_CONFIGURATION.md](SYSLOG_CONFIGURATION.md) for detailed configuration.

### Kerberos (Optional)

- **Purpose**: Single sign-on authentication
- **Package**: `krb5-user` (Debian) or `krb5-workstation` (RHEL)
- **Config**: `/etc/krb5.conf`

See [KERBEROS_SETUP.md](KERBEROS_SETUP.md) for detailed configuration.

## Deployment

### Full Infrastructure Deployment

```bash
cd ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml
```

### Individual Service Deployment

```bash
# NTP only
ansible-playbook -i inventory/production/hosts.yml playbooks/ntp-sync.yml

# Syslog only
ansible-playbook -i inventory/production/hosts.yml playbooks/syslog-server.yml

# Security hardening only
ansible-playbook -i inventory/production/hosts.yml playbooks/baseline-hardening.yml
```

### Using Tags

```bash
# Deploy only NTP and security
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml --tags ntp,security

# Skip Kerberos
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml --skip-tags kerberos
```

## Verification

### Check Service Status

```bash
# NTP
chronyc tracking
chronyc sources -v

# Syslog
systemctl status rsyslog
tail -f /var/log/syslog

# Security
sshd -t  # Test SSH config
```

### Test Time Synchronization

```bash
chronyc tracking
timedatectl status
```

### Test Syslog Forwarding

```bash
# Send test message
logger -t "test" "This is a test message"

# Check on syslog server
tail /var/log/remote/<hostname>/all.log
```

## Troubleshooting

### NTP Issues

1. **Clock not synchronized**
   ```bash
   chronyc makestep   # Force immediate sync
   chronyc tracking   # Check sync status
   ```

2. **Firewall blocking NTP**
   ```bash
   firewall-cmd --add-service=ntp --permanent
   firewall-cmd --reload
   ```

### Syslog Issues

1. **Logs not forwarding**
   - Check rsyslog is running: `systemctl status rsyslog`
   - Check connectivity: `nc -vz masternode 514`
   - Check configuration: `rsyslogd -N1`

2. **High log volume**
   - Check rate limiting in `/etc/rsyslog.conf`
   - Review logrotate configuration

### SSH Issues

1. **Connection refused after hardening**
   - Use console access to restore backup
   - Check SSH config: `sshd -t`
   - Review `/etc/ssh/sshd_config.d/99-hardening.conf`

## Related Documentation

- [Time Sync Setup](TIME_SYNC_SETUP.md)
- [Syslog Configuration](SYSLOG_CONFIGURATION.md)
- [Kerberos Setup](KERBEROS_SETUP.md)
- [Main README](../README.md)
