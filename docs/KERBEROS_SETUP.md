# Kerberos Setup

This document describes how to configure Kerberos authentication for the VMStation cluster.

## Overview

Kerberos provides:
- Single sign-on (SSO) across cluster nodes
- Secure service authentication
- Centralized identity management
- Strong cryptographic authentication

## Prerequisites

Before configuring Kerberos:

1. **Time Synchronization** - All nodes must be within 5 minutes
   - See [TIME_SYNC_SETUP.md](TIME_SYNC_SETUP.md)
   
2. **DNS Resolution** - Proper hostname resolution required
   - Forward and reverse DNS for all nodes
   
3. **Network Connectivity** - Kerberos ports must be open
   - TCP/UDP 88 (Kerberos)
   - TCP/UDP 464 (kpasswd)
   - TCP 749 (kadmin)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kerberos Infrastructure                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────┐        ┌─────────────────────────────┐ │
│  │   KDC Server    │        │         Clients            │ │
│  │   (masternode)  │        │                            │ │
│  │                 │        │  ┌─────────────────────┐   │ │
│  │ ┌─────────────┐ │        │  │  storagenodet3500  │   │ │
│  │ │     AS      │◄├────────┤  └─────────────────────┘   │ │
│  │ │ (Auth Svc)  │ │        │                            │ │
│  │ └─────────────┘ │        │  ┌─────────────────────┐   │ │
│  │                 │        │  │      homelab        │   │ │
│  │ ┌─────────────┐ │        │  └─────────────────────┘   │ │
│  │ │    TGS      │ │        │                            │ │
│  │ │(Ticket Svc) │ │        └─────────────────────────────┘ │
│  │ └─────────────┘ │                                        │
│  │                 │                                        │
│  │ ┌─────────────┐ │                                        │
│  │ │  kadmin     │ │                                        │
│  │ └─────────────┘ │                                        │
│  └─────────────────┘                                        │
│                                                              │
│  Realm: VMSTATION.LOCAL                                     │
└─────────────────────────────────────────────────────────────┘
```

## Configuration Options

### Option 1: Basic Kerberos (krb5)

Minimal Kerberos setup without full identity management.

**Use when:**
- You only need authentication
- You have existing user management
- You want simple setup

### Option 2: FreeIPA (Recommended)

Full identity management with Kerberos, LDAP, DNS, and CA.

**Use when:**
- You need centralized user/group management
- You want web-based administration
- You need certificate services

## Basic Kerberos Configuration

### Step 1: Configure Variables

In `ansible/inventory/production/group_vars/all.yml`:

```yaml
# Enable Kerberos
kerberos_enabled: true

# Kerberos realm (must be UPPERCASE)
kerberos_realm: VMSTATION.LOCAL

# Kerberos domain (must be lowercase)
kerberos_domain: vmstation.local

# KDC servers
kerberos_kdc_servers:
  - masternode

# Admin server
kerberos_admin_server: masternode
```

### Step 2: Deploy Configuration

```bash
cd ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/kerberos-setup.yml
```

### Step 3: Initialize KDC (Manual on Server)

On the KDC server (masternode):

```bash
# Initialize the Kerberos database
kdb5_util create -s

# Start KDC services
systemctl enable krb5kdc kadmin
systemctl start krb5kdc kadmin

# Create admin principal
kadmin.local -q "addprinc admin/admin"
```

### Step 4: Create User Principals

```bash
# Create user principal
kadmin.local -q "addprinc username"

# Create host principals (for each node)
kadmin.local -q "addprinc -randkey host/storagenodet3500.vmstation.local"
kadmin.local -q "addprinc -randkey host/homelab.vmstation.local"
```

## FreeIPA Configuration

### Step 1: Install FreeIPA Server

On the designated IPA server (typically masternode):

```bash
# Install packages (RHEL/CentOS)
dnf install ipa-server ipa-server-dns

# Run installer
ipa-server-install --realm=VMSTATION.LOCAL \
                   --domain=vmstation.local \
                   --ds-password=<directory_password> \
                   --admin-password=<admin_password> \
                   --setup-dns \
                   --no-host-dns \
                   --unattended
```

### Step 2: Enroll Clients

On each client node:

```bash
# Install IPA client
dnf install ipa-client  # RHEL
apt install freeipa-client  # Debian

# Enroll client
ipa-client-install --server=masternode \
                   --domain=vmstation.local \
                   --realm=VMSTATION.LOCAL \
                   --principal=admin \
                   --unattended
```

## Verification

### Check Kerberos Configuration

```bash
# Display Kerberos configuration
cat /etc/krb5.conf

# Test DNS for KDC
host -t SRV _kerberos._tcp.vmstation.local
```

### Get a Ticket

```bash
# Obtain ticket-granting ticket
kinit username

# List tickets
klist

# Destroy tickets
kdestroy
```

### Example klist Output

```
Ticket cache: KEYRING:persistent:1000:1000
Default principal: admin@VMSTATION.LOCAL

Valid starting       Expires              Service principal
11/29/2024 12:00:00  11/30/2024 12:00:00  krbtgt/VMSTATION.LOCAL@VMSTATION.LOCAL
        renew until 12/06/2024 12:00:00
```

## SSSD Integration

SSSD provides caching and offline authentication:

### Configuration

**Location**: `/etc/sssd/sssd.conf`

```ini
[sssd]
services = nss, pam, ssh
config_file_version = 2
domains = vmstation.local

[domain/vmstation.local]
id_provider = files
auth_provider = krb5
access_provider = simple
cache_credentials = True
krb5_realm = VMSTATION.LOCAL
krb5_server = masternode
```

### Enable SSSD

```bash
systemctl enable sssd
systemctl start sssd
```

## PAM Integration

Enable Kerberos authentication in PAM:

### Debian/Ubuntu

```bash
pam-auth-update --enable krb5
```

### RHEL/CentOS

```bash
authselect select sssd --force
```

## Troubleshooting

### Cannot Get Initial Credentials

1. **Check time sync**
   ```bash
   chronyc tracking
   # Time must be within 5 minutes of KDC
   ```

2. **Check DNS**
   ```bash
   host masternode
   host -t SRV _kerberos._tcp.vmstation.local
   ```

3. **Check KDC connectivity**
   ```bash
   nc -vz masternode 88
   ```

### Ticket Expired

```bash
# Renew ticket
kinit -R

# Or get new ticket
kdestroy
kinit username
```

### Password Change Issues

```bash
# Change password via kpasswd
kpasswd username

# Or via kadmin
kadmin -q "cpw username"
```

### SSSD Not Working

1. **Check SSSD status**
   ```bash
   systemctl status sssd
   ```

2. **Clear SSSD cache**
   ```bash
   sss_cache -E
   systemctl restart sssd
   ```

3. **Check SSSD logs**
   ```bash
   tail -f /var/log/sssd/sssd.log
   ```

## Best Practices

### For Security

1. **Strong passwords** for all principals
2. **Regular password rotation**
3. **Use keytabs** for service accounts
4. **Enable encryption types** (AES only)
5. **Audit Kerberos logs**

### For High Availability

1. **Multiple KDC servers** (master + replicas)
2. **DNS round-robin** for KDC discovery
3. **Replicate keytabs** securely
4. **Monitor KDC health**

### For Operations

1. **Document all principals**
2. **Backup KDC database** regularly
3. **Test authentication** after changes
4. **Keep credentials cached** with SSSD

## Related Documentation

- [Infrastructure Services](INFRASTRUCTURE_SERVICES.md)
- [Time Sync Setup](TIME_SYNC_SETUP.md) (Required for Kerberos)
- [MIT Kerberos Documentation](https://web.mit.edu/kerberos/)
- [FreeIPA Documentation](https://www.freeipa.org/page/Documentation)
