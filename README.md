# VMStation Cluster Configuration

**Status**: ✓ Production Baseline Captured (2025-11-29)  
**Hosts**: 3 (masternode, storagenodet3500, homelab)  
**Coverage**: SSH, Network, Mounts, Systemd, Kernel Parameters, NTP, Syslog, Security Hardening

This repository tracks and enforces the desired state of all critical machine configurations to prevent drift and ensure reliable, repeatable setups across reboots, upgrades, and scaling events.

## Purpose

- Combat configuration drift across your infrastructure
- Ensure stable, reproducible machine setups
- Version control all critical system configurations
- Enable automated validation and enforcement of desired state
- Provide standardized infrastructure services (NTP, Syslog, Security)


## Repository Structure

```
cluster-config/
├── README.md                          # This file
├── IMPROVEMENTS_AND_STANDARDS.md      # Best practices and standards
├── ansible/                           # Ansible directory structure
├── hosts/                             # Per-host configuration files
├── group/                             # Shared configs for groups
├── manifests/                         # Kubernetes manifests
├── templates/                         # Jinja2 templates
├── playbooks/                         # Legacy playbooks
├── roles/                             # Legacy roles
├── inventory/hosts.ini                # Legacy inventory
└── scripts/                           # Helper scripts
```

## Documentation

All detailed infrastructure and configuration documentation has been centralized in the [cluster-docs/components/](../cluster-docs/components/) directory. Please refer to that location for:
- Infrastructure services
- Kerberos setup
- Syslog configuration
- Time sync setup

This repository only contains the README and improvements/standards documentation.

## Quick Start

### Option 1: New Infrastructure Services (Recommended)

Deploy the complete infrastructure baseline with the new playbooks:

```bash
cd ansible

# Deploy all infrastructure services
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml

# Or deploy individual services
ansible-playbook -i inventory/production/hosts.yml playbooks/ntp-sync.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/syslog-server.yml
ansible-playbook -i inventory/production/hosts.yml playbooks/baseline-hardening.yml
```

### Option 2: Legacy Configuration Management

Use the original playbooks for per-host configuration:

```bash
# Gather configurations from running systems
./scripts/gather-config.sh <hostname> <os-type>
```

This will collect:
- SSH configuration (`/etc/ssh/sshd_config`)
- Filesystem mounts (`/etc/fstab`)
- Network configuration (varies by OS)
- System parameters (`/etc/sysctl.conf`)

### Review and Commit

Review the gathered configurations, remove any sensitive data, and commit to version control:

```bash
git add hosts/<os-type>/<hostname>/
git commit -m "Add configuration for <hostname>"
git push
```

### Apply Configuration

Use Ansible to enforce the desired state:

```bash
# Using new playbooks (recommended)
cd ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml

# Using legacy playbooks
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml
```

### Validate and Check Drift

Regularly check for configuration drift:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/validate-config.yml
```

Or use the standalone script:

```bash
./scripts/check-drift.sh
```

## Infrastructure Services

The new `ansible/` directory provides standardized infrastructure services:

### Time Synchronization (NTP/Chrony)

Ensures consistent time across all cluster nodes:

```bash
cd ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/ntp-sync.yml
```

See [docs/TIME_SYNC_SETUP.md](docs/TIME_SYNC_SETUP.md) for detailed configuration.

### Centralized Logging (Syslog)

Aggregates logs from all nodes to a central server:

```bash
cd ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/syslog-server.yml
```

See [docs/SYSLOG_CONFIGURATION.md](docs/SYSLOG_CONFIGURATION.md) for detailed configuration.

### Security Hardening

Applies baseline security configurations:

```bash
cd ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/baseline-hardening.yml
```

Includes:
- SSH hardening with modern algorithms
- Kernel security parameters
- Password policy enforcement
- Audit logging

### Kerberos (Optional)

Single sign-on authentication:

```bash
cd ansible
ansible-playbook -i inventory/production/hosts.yml playbooks/kerberos-setup.yml
```

See [docs/KERBEROS_SETUP.md](docs/KERBEROS_SETUP.md) for detailed configuration.

### Using Tags for Selective Deployment

```bash
# Deploy only NTP
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml --tags ntp

# Deploy only security hardening
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml --tags security

# Skip Kerberos
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml --skip-tags kerberos
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

## Related Documentation

### Infrastructure Services
- [Infrastructure Services Overview](docs/INFRASTRUCTURE_SERVICES.md)
- [Time Sync Setup](docs/TIME_SYNC_SETUP.md)
- [Syslog Configuration](docs/SYSLOG_CONFIGURATION.md)
- [Kerberos Setup](docs/KERBEROS_SETUP.md)

### Standards and Improvements
- [Improvements and Standards](IMPROVEMENTS_AND_STANDARDS.md)
- [Quick Start Guide](QUICK_START.md)
- [Baseline Report](BASELINE_REPORT.md)
- [Deployment Summary](DEPLOYMENT_SUMMARY.md)

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

