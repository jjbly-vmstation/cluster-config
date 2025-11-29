# Machine Configuration Quick Start Guide

Get your machine configuration management up and running in minutes.

## Prerequisites

- Ansible 2.9 or higher
- SSH access to target hosts
- sudo/root privileges on target hosts
- Git for version control

## Step 1: Initial Setup

### Clone or Initialize Repository

If starting fresh:
```bash
git init
git add .
git commit -m "Initial machine configuration repository"
```

If this is already in a repo:
```bash
git pull origin main
```

### Configure Ansible Inventory

Edit `inventory/hosts.ini` to add your hosts:

```ini
[debian12]
web-01 ansible_host=192.168.1.10
web-02 ansible_host=192.168.1.11

[rhel10]
db-01 ansible_host=192.168.1.20
db-02 ansible_host=192.168.1.21
```

## Step 2: Gather Current Configurations

For each host, collect its current configuration:

```bash
# SSH to the host first
ssh root@web-01

# On the host, run the gather script
cd /path/to/machine-config-repo
./scripts/gather-config.sh web-01 debian12
```

This collects:
- SSH configuration
- Filesystem mounts (fstab)
- Network configuration
- System parameters
- Time sync configuration

## Step 3: Review and Sanitize

**CRITICAL**: Before committing, review the gathered configs:

```bash
cd hosts/debian12/
ls -la

# Check for sensitive data
grep -r "password" .
grep -r "secret" .
grep -r "key" .
```

Remove or redact:
- Passwords
- Private keys
- API tokens
- Internal IP addresses (if sensitive)
- Sensitive hostnames

## Step 4: Commit to Version Control

```bash
git add hosts/debian12/
git commit -m "Add configuration for web-01 (Debian 12)"
git push origin main
```

## Step 5: Apply Configuration to Other Hosts

Now you can enforce this configuration on other hosts:

```bash
# Test first (dry-run)
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --check

# Apply to all hosts
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml

# Apply to specific host
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --limit web-02

# Apply specific role only
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --tags ssh
```

## Step 6: Validate Configuration

Check for drift between repository and live systems:

```bash
# Using Ansible
ansible-playbook -i inventory/hosts.ini playbooks/validate-config.yml

# Using standalone script (run on target host)
ssh root@web-01
cd /path/to/machine-config-repo
./scripts/check-drift.sh debian12
```

## Common Use Cases

### Use Case 1: Add a New Host

```bash
# 1. Add to inventory
echo "web-03 ansible_host=192.168.1.12" >> inventory/hosts.ini

# 2. Gather its config
ssh root@web-03
./scripts/gather-config.sh web-03 debian12

# 3. Review and commit
git add hosts/debian12/ inventory/hosts.ini
git commit -m "Add web-03"

# 4. Or apply existing config to it
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --limit web-03
```

### Use Case 2: Update SSH Configuration

```bash
# 1. Edit the config file
vim hosts/debian12/sshd_config

# 2. Commit the change
git add hosts/debian12/sshd_config
git commit -m "Disable root login for security"

# 3. Test on one host first
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --limit web-01 --tags ssh

# 4. Roll out to all hosts
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --tags ssh
```

### Use Case 3: Detect and Fix Drift

```bash
# 1. Run drift detection
ansible-playbook -i inventory/hosts.ini playbooks/validate-config.yml

# 2. If drift is found and unwanted, re-apply config
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --limit web-01

# 3. If drift is legitimate, update repo
ssh root@web-01
./scripts/gather-config.sh web-01 debian12
git add hosts/debian12/
git commit -m "Update web-01 config (legitimate change)"
```

### Use Case 4: Add New Network Interface

```bash
# 1. Configure interface on one host manually
ssh root@web-01
# Configure network...

# 2. Gather the new config
./scripts/gather-config.sh web-01 debian12

# 3. Review network config changes
git diff hosts/debian12/interfaces
# or
git diff hosts/debian12/systemd-networkd/

# 4. Commit if correct
git add hosts/debian12/
git commit -m "Add eth1 configuration"

# 5. Apply to other hosts
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --tags networking
```

## Scheduled Drift Detection

Set up a cron job or systemd timer to detect drift automatically:

### Using Cron

```bash
# Add to crontab
crontab -e

# Run drift check daily at 2 AM
0 2 * * * cd /path/to/machine-config-repo && ansible-playbook -i inventory/hosts.ini playbooks/validate-config.yml > /var/log/config-drift.log 2>&1
```

### Using Systemd Timer

```ini
# /etc/systemd/system/config-drift-check.service
[Unit]
Description=Configuration Drift Check
After=network.target

[Service]
Type=oneshot
WorkingDirectory=/path/to/machine-config-repo
ExecStart=/usr/bin/ansible-playbook -i inventory/hosts.ini playbooks/validate-config.yml
User=root
```

```ini
# /etc/systemd/system/config-drift-check.timer
[Unit]
Description=Daily Configuration Drift Check
Requires=config-drift-check.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
# Enable and start timer
systemctl enable config-drift-check.timer
systemctl start config-drift-check.timer
systemctl status config-drift-check.timer
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/validate-config.yml
name: Validate Configuration

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.x'
      
      - name: Install Ansible
        run: |
          pip install ansible
      
      - name: Run validation
        run: |
          ansible-playbook -i inventory/hosts.ini playbooks/validate-config.yml
        env:
          ANSIBLE_HOST_KEY_CHECKING: False
      
      - name: Notify on drift
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Configuration Drift Detected',
              body: 'Automated drift detection found discrepancies. Please investigate.'
            })
```

## Troubleshooting

### Problem: "Permission denied" when gathering config

**Solution**: Run with sudo or as root
```bash
sudo ./scripts/gather-config.sh hostname debian12
```

### Problem: Ansible can't connect to hosts

**Solution**: Check SSH connectivity and inventory
```bash
ansible all -i inventory/hosts.ini -m ping
ssh -vvv root@target-host
```

### Problem: Configuration won't apply

**Solution**: Run in check mode first to see what would change
```bash
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --check --diff
```

### Problem: Network configuration breaks connectivity

**Solution**: 
1. Always test network changes on a non-critical host first
2. Have console access available (IPMI, KVM)
3. Use a script with automatic rollback:

```bash
#!/bin/bash
# Safe network config apply
cp /etc/network/interfaces /etc/network/interfaces.backup
# Apply new config
systemctl restart networking
# Wait 30 seconds
sleep 30
# If you're still connected, config is good
# Otherwise, it will auto-rollback
```

## Best Practices

1. **Always test in staging first**: Never apply untested configs to production
2. **Use git branches**: Create feature branches for major changes
3. **Document changes**: Write clear commit messages explaining why
4. **Backup before apply**: The playbooks create backups, but verify they exist
5. **Monitor after changes**: Watch logs and metrics after applying configs
6. **Use tags for selective apply**: Don't re-apply everything if only SSH changed
7. **Keep secrets out**: Never commit passwords or keys
8. **Regular validation**: Run drift detection at least daily
9. **Version pin Ansible**: Document which Ansible version you're using
10. **Test rollback procedures**: Practice reverting changes before you need to

## Next Steps

1. **Set up monitoring**: Integrate with your monitoring system to alert on drift
2. **Document your configs**: Add comments to configuration files explaining settings
3. **Create runbooks**: Document common operations and troubleshooting steps
4. **Train the team**: Ensure everyone knows how to use the system
5. **Expand coverage**: Add more hosts and configuration types over time

## Resources

- [Main README](README.md) - Full documentation
- [Ansible Documentation](https://docs.ansible.com/)
- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/config)
- [Systemd Network Configuration](https://www.freedesktop.org/software/systemd/man/systemd.network.html)
- [NetworkManager Configuration](https://networkmanager.dev/docs/api/latest/)

## Support

- Open an issue in this repository
- Check existing issues for solutions
- Consult the team documentation wiki
- Contact the infrastructure team

---

**Quick Reference Commands**

```bash
# Gather config from host
./scripts/gather-config.sh <hostname> <debian12|rhel10>

# Check for drift
./scripts/check-drift.sh <debian12|rhel10>

# Apply all configs
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml

# Apply to specific host
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --limit hostname

# Apply specific role
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --tags ssh

# Validate configs
ansible-playbook -i inventory/hosts.ini playbooks/validate-config.yml

# Test before applying
ansible-playbook -i inventory/hosts.ini playbooks/apply-config.yml --check --diff
```
