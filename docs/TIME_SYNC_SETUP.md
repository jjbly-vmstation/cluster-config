# Time Synchronization Setup

This document describes how to configure NTP/Chrony time synchronization for the VMStation cluster.

## Overview

Accurate time is critical for:
- Kubernetes certificate validation
- Log correlation across nodes
- Distributed system coordination
- Kerberos authentication (if enabled)
- TLS certificate validation

## Chrony vs NTP

We use **Chrony** instead of traditional NTPd because:
- Better handling of intermittent network connections
- Faster initial synchronization
- More accurate time tracking
- Active development and security updates

## Configuration

### Default NTP Servers

The default configuration uses public NTP pool servers:

```yaml
ntp_servers:
  - 0.pool.ntp.org
  - 1.pool.ntp.org
  - 2.pool.ntp.org
  - 3.pool.ntp.org
```

### Customizing NTP Servers

To use internal NTP servers, update `ansible/inventory/production/group_vars/all.yml`:

```yaml
ntp_servers:
  - ntp1.internal.company.com
  - ntp2.internal.company.com
  - 0.pool.ntp.org  # Fallback
```

### Chrony Configuration Template

The chrony configuration is generated from `templates/chrony.conf.j2`:

```
server 0.pool.ntp.org iburst
server 1.pool.ntp.org iburst
server 2.pool.ntp.org iburst
server 3.pool.ntp.org iburst

driftfile /var/lib/chrony/drift
rtcsync
makestep 1.0 3
logdir /var/log/chrony
```

### Key Settings

| Setting | Purpose | Default |
|---------|---------|---------|
| `iburst` | Fast initial sync (4 packets instead of 1) | Enabled |
| `driftfile` | Tracks clock drift between restarts | `/var/lib/chrony/drift` |
| `rtcsync` | Sync hardware clock periodically | Enabled |
| `makestep 1.0 3` | Allow time jumps up to 1 sec for first 3 updates | Enabled |

## Deployment

### Deploy NTP to All Hosts

```bash
cd ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/ntp-sync.yml
```

### Deploy to Specific Host

```bash
ansible-playbook -i inventory/production/hosts.yml playbooks/ntp-sync.yml --limit masternode
```

### Check Mode (Dry Run)

```bash
ansible-playbook -i inventory/production/hosts.yml playbooks/ntp-sync.yml --check --diff
```

## Verification

### Check Chrony Status

```bash
# View synchronization status
chronyc tracking

# View NTP sources
chronyc sources -v

# View source statistics
chronyc sourcestats
```

### Example Output

```
Reference ID    : A29FC87B (time.cloudflare.com)
Stratum         : 3
Ref time (UTC)  : Thu Nov 29 12:00:00 2024
System time     : 0.000000123 seconds fast of NTP time
Last offset     : +0.000000456 seconds
RMS offset      : 0.000001234 seconds
Frequency       : 1.234 ppm slow
Residual freq   : +0.001 ppm
Skew            : 0.012 ppm
Root delay      : 0.012345678 seconds
Root dispersion : 0.001234567 seconds
Update interval : 64.0 seconds
Leap status     : Normal
```

### Check System Time

```bash
# Show date and time status
timedatectl status

# Expected output should show:
#   NTP synchronized: yes
#   NTP service: active
```

## Troubleshooting

### Clock Not Synchronized

1. **Check chrony is running**
   ```bash
   systemctl status chrony  # Debian
   systemctl status chronyd # RHEL
   ```

2. **Check NTP server connectivity**
   ```bash
   chronyc sources -v
   # Look for "?" or "-" in the first column indicating issues
   ```

3. **Force time synchronization**
   ```bash
   chronyc makestep
   ```

4. **Check firewall**
   ```bash
   # NTP uses UDP port 123
   firewall-cmd --list-all | grep ntp
   # Or check with netstat
   ss -ulnp | grep 123
   ```

### Large Time Offset

If the time offset is too large (more than a few seconds):

```bash
# Allow immediate large time jump
chronyc makestep

# Or restart chronyd
systemctl restart chrony  # Debian
systemctl restart chronyd # RHEL
```

### Clock Drifting

1. **Check drift file**
   ```bash
   cat /var/lib/chrony/drift
   # Value should be stable and not extremely large
   ```

2. **Monitor tracking over time**
   ```bash
   watch -n 10 chronyc tracking
   ```

3. **Consider hardware clock issues**
   - Check BIOS/UEFI clock
   - Consider RTC battery replacement

## Best Practices

### For Production

1. **Use multiple NTP servers** (minimum 3-4)
2. **Mix local and external servers** for redundancy
3. **Monitor time drift** with alerting
4. **Consider local NTP server** for air-gapped environments

### For Security

1. **Restrict NTP client access** on server mode
2. **Use authenticated NTP** for critical systems
3. **Monitor for NTP amplification attacks**

### For Kubernetes

1. **Ensure all nodes are synchronized** before cluster operations
2. **Allow time for sync** after node reboot
3. **Monitor certificate expiration** which depends on time

## Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ntp_servers` | List of NTP servers | `[0-3].pool.ntp.org` |
| `chrony_iburst` | Enable iburst for faster sync | `true` |
| `chrony_makestep_threshold` | Max time jump allowed | `1.0` |
| `chrony_makestep_limit` | Number of updates for makestep | `3` |
| `chrony_is_server` | Act as NTP server | `false` |
| `chrony_allow_networks` | Networks allowed for NTP clients | `['127.0.0.1']` |

## Related Documentation

- [Infrastructure Services](INFRASTRUCTURE_SERVICES.md)
- [Chrony Documentation](https://chrony.tuxfamily.org/documentation.html)
- [NTP Pool Project](https://www.ntppool.org/)
