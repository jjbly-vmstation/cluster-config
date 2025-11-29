# cluster-config
# VMStation Machine Configuration  Tracks and enforces the baseline configuration for all VMStation machines.  - Per-host and group configs - Ansible playbooks and roles - Drift detection scripts  See the organization README for cross-repo context.
=======
# VMStation Machine Configuration

**Status**: ✓ Production Baseline Captured (2025-11-29)  
**Hosts**: 3 (masternode, storagenodet3500, homelab)  
**Coverage**: SSH, Network, Mounts, Systemd, Kernel Parameters

This repository tracks and enforces the desired state of all critical machine configurations to prevent drift and ensure reliable, repeatable setups across reboots, upgrades, and scaling events.

## Purpose

- Combat configuration drift across your infrastructure
- Ensure stable, reproducible machine setups
- Version control all critical system configurations
- Enable automated validation and enforcement of desired state

## Repository Structure

```
machine-config-repo/
├── README.md                      # This file
├── hosts/                         # Per-host configuration files
│   ├── debian12/                  # Debian 12 (Bookworm) hosts
│   │   ├── sshd_config           # SSH daemon configuration
│   │   ├── fstab                  # Filesystem mount table
│   │   ├── interfaces             # Network interfaces (ifupdown)
│   │   └── systemd-networkd/      # systemd-networkd configs
│   └── rhel10/                    # RHEL 10 hosts
│       ├── sshd_config           # SSH daemon configuration
│       ├── fstab                  # Filesystem mount table
│       ├── ifcfg-eth0             # Legacy network scripts
│       └── NetworkManager/        # NetworkManager connection files
├── group/                         # Shared configs for groups of machines
│   ├── common/                    # Configs applied to all machines
│   │   ├── ssh-hardening.conf    # SSH security settings
│   │   ├── ntp.conf               # Time synchronization
│   │   └── sysctl.conf            # Kernel parameters
│   └── storage/                   # Storage node specific configs
│       └── mount-templates/       # Common mount patterns
├── playbooks/                     # Ansible playbooks
│   ├── apply-config.yml          # Apply configurations to hosts
│   └── validate-config.yml        # Validate and check for drift
├── roles/                         # Ansible roles
│   ├── ssh/                       # SSH configuration management
│   ├── storage/                   # Storage and mount management
│   ├── networking/                # Network configuration
│   └── system/                    # System-level settings
├── inventory/                     # Ansible inventory
│   └── hosts.ini                  # Host and group definitions
└── scripts/                       # Helper scripts
    ├── gather-config.sh          # Collect current configurations
    └── check-drift.sh            # Detect configuration drift
```

## Quick Start

### 1. Gather Current Configurations

Use the provided script to collect configurations from your running systems:

```bash
./scripts/gather-config.sh <hostname> <os-type>
```

This will collect:
- SSH configuration (`/etc/ssh/sshd_config`)
- Filesystem mounts (`/etc/fstab`)
- Network configuration (varies by OS)
- System parameters (`/etc/sysctl.conf`)

### 2. Review and Commit

Review the gathered configurations, remove any sensitive data, and commit to version control:

```bash
git add hosts/<os-type>/<hostname>/
git commit -m "Add configuration for <hostname>"
git push
```

### 3. Apply Configuration

Use Ansible to enforce the desired state:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml
```

### 4. Validate and Check Drift

Regularly check for configuration drift:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/validate-config.yml
```

Or use the standalone script:

```bash
./scripts/check-drift.sh
```

## Configuration Examples

### SSH Configuration

**Location**: `hosts/<os-type>/sshd_config`

Critical SSH settings to version control:
- Port and listen addresses
- Authentication methods
- Security hardening options
- Banner and logging

**Role**: `roles/ssh/`

### Disk Mounts

**Location**: `hosts/<os-type>/fstab`

Mount configurations using UUIDs for stability:
- Persistent storage mounts
- NFS shares
- tmpfs configurations

**Role**: `roles/storage/`

### Networking

#### Debian 12

**ifupdown** (traditional): `hosts/debian12/interfaces`
```
auto eth0
iface eth0 inet static
    address 192.168.1.10/24
    gateway 192.168.1.1
```

**systemd-networkd**: `hosts/debian12/systemd-networkd/*.network`
```ini
[Match]
Name=eth0

[Network]
Address=192.168.1.10/24
Gateway=192.168.1.1
DNS=192.168.1.1
```

#### RHEL 10

**NetworkManager keyfiles**: `hosts/rhel10/NetworkManager/*.nmconnection`
```ini
[connection]
id=eth0
type=ethernet
interface-name=eth0

[ipv4]
method=manual
address1=192.168.1.10/24,192.168.1.1
dns=192.168.1.1
```

**Legacy scripts**: `hosts/rhel10/ifcfg-eth0` (if applicable)

**Role**: `roles/networking/`

## Drift Detection

Configuration drift occurs when live system state diverges from the version-controlled desired state. This can happen due to:
- Manual emergency changes
- Automated tools making untracked changes
- System updates modifying defaults
- Hardware/driver changes

### Automated Drift Detection

The `check-drift.sh` script compares live configurations against the repository:

```bash
#!/bin/bash
# Compare live configs with repo
diff /etc/ssh/sshd_config hosts/$(hostname)/sshd_config
```

### CI/CD Integration

Set up scheduled jobs to:
1. Run drift detection daily
2. Alert on differences
3. Auto-remediate or create tickets

## Best Practices

### Security

- **Never commit secrets**: Use Ansible Vault or external secrets management
- **Sanitize before commit**: Remove sensitive data (IPs, passwords, keys)
- **Use templates with variables**: Keep environment-specific data separate
- **Restrict repository access**: Only infrastructure team should have write access

### Organization

- **One host, one directory**: Keep each host's configs isolated
- **Use groups for shared configs**: Don't duplicate common settings
- **Document changes**: Write clear commit messages
- **Tag releases**: Mark stable configurations

### Automation

- **Idempotent operations**: Use Ansible/Salt for safe re-application
- **Test before apply**: Validate in staging first
- **Incremental rollout**: Apply to hosts gradually
- **Rollback plan**: Keep previous versions accessible

### Maintenance

- **Regular audits**: Review and update configurations quarterly
- **Remove obsolete configs**: Delete configs for decommissioned hosts
- **Update roles**: Keep Ansible roles current with best practices
- **Monitor compliance**: Track which hosts are in desired state

## Tools and Technologies

### Configuration Management

- **Ansible**: Primary tool for applying configurations
- **SaltStack**: Alternative for event-driven configuration
- **Puppet/Chef**: Traditional CM tools

### Drift Detection

- **Ansible Check Mode**: Dry-run to detect changes
- **Custom Scripts**: Shell scripts for simple comparisons
- **InSpec**: Compliance and validation framework

### Secrets Management

- **Ansible Vault**: Encrypted variables in Ansible
- **HashiCorp Vault**: Enterprise secrets management
- **Git-crypt**: Transparent file encryption in git

## Workflow

### Adding a New Host

1. Provision the host with base OS
2. Run `gather-config.sh` to collect initial state
3. Review and sanitize configurations
4. Add to `inventory/hosts.ini`
5. Commit configurations to repository
6. Apply desired state with `apply-config.yml`

### Updating Configuration

1. Edit configuration file in repository
2. Review changes with `git diff`
3. Commit with descriptive message
4. Test in staging environment first
5. Apply to production with Ansible
6. Validate with `validate-config.yml`

### Handling Drift

1. Detect drift with `check-drift.sh` or scheduled job
2. Investigate cause of drift
3. Decide: update repository or remediate host
4. If legitimate change: update repository
5. If unwanted drift: re-apply configuration
6. Document incident and root cause

## Troubleshooting

### Common Issues

**Problem**: Configuration won't apply
- Check Ansible syntax: `ansible-playbook --syntax-check`
- Verify host connectivity: `ansible all -m ping`
- Review role dependencies

**Problem**: Drift detected but no actual change
- Check file permissions and ownership
- Compare content vs. metadata
- Review timestamp-based tools

**Problem**: Sensitive data in repository
- Remove from history: `git filter-branch` or BFG Repo-Cleaner
- Rotate compromised credentials immediately
- Update access controls

## References

- [GitOps for Infrastructure](https://www.weave.works/technologies/gitops/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Infrastructure as Code](https://martinfowler.com/bliki/InfrastructureAsCode.html)
- [The 12-Factor App](https://12factor.net/)
- [Configuration Drift Detection](https://www.puppet.com/docs/puppet/latest/quick_start_essential_config.html)

## Contributing

1. Create a feature branch
2. Make changes
3. Test in non-production environment
4. Submit pull request with clear description
5. Wait for review and approval
6. Merge to main branch

## License

[Specify your license here]

## Support

For issues or questions:
- Create an issue in this repository
- Contact the infrastructure team
- Refer to the documentation wiki

