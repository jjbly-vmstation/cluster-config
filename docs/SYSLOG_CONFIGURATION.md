# Syslog Configuration

This document describes how to configure centralized logging with rsyslog for the VMStation cluster.

## Overview

Centralized logging provides:
- Single point for log aggregation
- Easier troubleshooting across nodes
- Long-term log retention
- Security audit trails

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  masternode     │     │ storagenodet    │     │    homelab      │
│  (Syslog Server)│◄────│  (Client)       │     │   (Client)      │
│                 │     └─────────────────┘     └────────┬────────┘
│  /var/log/      │                                      │
│    remote/      │◄─────────────────────────────────────┘
│      hostname/  │
│        *.log    │
└─────────────────┘
```

## Configuration

### Server Configuration

The syslog server (typically masternode) receives and stores logs from all nodes.

**Location**: `/etc/rsyslog.d/10-server.conf`

```
# Load UDP module for receiving logs
module(load="imudp")
input(type="imudp" port="514")

# Load TCP module for receiving logs
module(load="imtcp")
input(type="imtcp" port="514")

# Template for remote logs
template(name="RemoteLogs" type="string"
         string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")

# Store remote logs by hostname
if $fromhost-ip != "127.0.0.1" then ?RemoteLogs
& stop
```

### Client Configuration

Clients forward logs to the central server.

**Location**: `/etc/rsyslog.d/10-forward.conf`

```
# Forward all logs to syslog server (UDP)
*.* @masternode:514

# For TCP (more reliable), use:
# *.* @@masternode:514
```

## Deployment

### Deploy Syslog to All Hosts

```bash
cd ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/syslog-server.yml
```

### Deploy Server Only

```bash
ansible-playbook -i inventory/production/hosts.yml playbooks/syslog-server.yml --limit masternode
```

### Deploy Clients Only

```bash
ansible-playbook -i inventory/production/hosts.yml playbooks/syslog-server.yml --limit '!masternode'
```

## Variables

Configure in `ansible/inventory/production/group_vars/all.yml`:

```yaml
# Syslog server (receives logs)
syslog_server: masternode

# Port for syslog
syslog_port: 514

# Protocol: udp or tcp
syslog_protocol: udp

# Log retention (days)
syslog_retention_days: 90
```

## Log Locations

### On Syslog Server (masternode)

| Path | Contents |
|------|----------|
| `/var/log/remote/` | Root for remote logs |
| `/var/log/remote/<hostname>/` | Logs from specific host |
| `/var/log/remote/<hostname>/sshd.log` | SSH logs from host |
| `/var/log/remote/<hostname>/all.log` | All logs from host |

### On All Hosts (Local)

| Path | Contents |
|------|----------|
| `/var/log/syslog` | General system log (Debian) |
| `/var/log/messages` | General system log (RHEL) |
| `/var/log/auth.log` | Authentication logs |
| `/var/log/secure` | Security logs (RHEL) |

## Log Rotation

Remote logs are rotated daily with configuration in `/etc/logrotate.d/rsyslog-remote`:

```
/var/log/remote/*/*.log {
    daily
    missingok
    rotate 90
    compress
    delaycompress
    notifempty
    create 0640 syslog adm
    sharedscripts
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}
```

## Verification

### Check RSyslog Status

```bash
systemctl status rsyslog
```

### Test Logging

```bash
# Send test message
logger -t "test" "This is a test message from $(hostname)"

# Check local log
tail /var/log/syslog  # Debian
tail /var/log/messages  # RHEL

# Check on server (for remote hosts)
tail /var/log/remote/$(hostname)/test.log
```

### Check Forwarding

```bash
# On client, check queue status
rsyslogd -N1

# Check connectivity to server
nc -vz masternode 514
```

## Advanced Configuration

### TCP with Queuing (Reliable Delivery)

For more reliable log delivery, use TCP with disk-assisted queuing:

```
# Forward configuration with queue
action(type="omfwd" target="masternode" port="514" protocol="tcp"
       queue.type="LinkedList"
       queue.filename="forward"
       queue.maxdiskspace="1g"
       queue.saveonshutdown="on"
       action.resumeRetryCount="-1")
```

### TLS Encryption

For encrypted syslog (recommended for sensitive environments):

1. **Generate certificates** for server and clients
2. **Configure server** with TLS listener
3. **Configure clients** with TLS forwarding

See the Ansible role for TLS configuration details.

### Log Filtering

Filter specific log levels or facilities:

```
# Forward only errors and above
*.err @masternode:514

# Forward specific facilities
auth.* @masternode:514
authpriv.* @masternode:514

# Exclude debug messages
*.info;*.!debug @masternode:514
```

## Troubleshooting

### Logs Not Forwarding

1. **Check rsyslog is running**
   ```bash
   systemctl status rsyslog
   ```

2. **Check connectivity**
   ```bash
   nc -vz masternode 514
   ```

3. **Check firewall**
   ```bash
   # On server
   firewall-cmd --add-port=514/udp --permanent
   firewall-cmd --add-port=514/tcp --permanent
   firewall-cmd --reload
   ```

4. **Validate configuration**
   ```bash
   rsyslogd -N1
   ```

### High Log Volume

1. **Implement rate limiting**
   ```
   module(load="imuxsock" SysSock.RateLimit.Interval="5"
                          SysSock.RateLimit.Burst="200")
   ```

2. **Filter noisy applications**
   ```
   if $programname == 'noisy-app' then stop
   ```

3. **Adjust log rotation**
   - Increase rotation frequency
   - Decrease retention period
   - Enable compression

### Disk Space Issues

1. **Check log sizes**
   ```bash
   du -sh /var/log/remote/*
   ```

2. **Force rotation**
   ```bash
   logrotate -f /etc/logrotate.d/rsyslog-remote
   ```

3. **Reduce retention**
   - Update `syslog_retention_days` variable
   - Re-run playbook

## Best Practices

### For Production

1. **Use TCP** for reliable delivery
2. **Enable TLS** for security
3. **Implement rate limiting** to prevent flood
4. **Monitor disk space** on syslog server
5. **Set up log analysis** (Loki, ELK, Graylog)

### For Security

1. **Restrict access** to log files
2. **Use separate partition** for logs
3. **Encrypt sensitive logs** in transit
4. **Implement log integrity** checking
5. **Set up alerts** for security events

## Related Documentation

- [Infrastructure Services](INFRASTRUCTURE_SERVICES.md)
- [RSyslog Documentation](https://www.rsyslog.com/doc/)
- [Logrotate Manual](https://linux.die.net/man/8/logrotate)
