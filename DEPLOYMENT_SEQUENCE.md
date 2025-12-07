# VMStation Cluster Deployment Sequence

This file documents the recommended order and commands for deploying the full stack, including identity, baseline, infrastructure, cluster, and monitoring. Use this as a reference for manual operations or CI/CD pipeline automation.

## 0. Workspace Preparation
Clone all required organization repositories into `/opt/vmstation-org` on your deployment host:
```
ORG="jjbly-vmstation"
TARGET="/opt/vmstation-org"
sudo mkdir -p "$TARGET"
sudo chown jjbly:jjbly /opt/vmstation-org
cd "$TARGET"
for repo in cluster-setup cluster-config cluster-cicd cluster-monitor-stack cluster-application-stack cluster-infra cluster-tools cluster-docs; do
	if [ -d "$repo/.git" ]; then
		echo "Updating $repo..."
		cd "$repo" && git pull && cd ..
	else
		echo "Cloning $repo..."
		git clone "https://github.com/$ORG/$repo.git"
	fi
done
cd ..
```
This ensures all required codebases are present for subsequent steps.

## 1. Bootstrap Identity & SSO
**Important:**
For each deployment phase, always change directory (`cd`) into the relevant repo before running Ansible commands. This ensures the correct `ansible.cfg`, inventory, and roles are used for that phase.

**Example (Bootstrap Phase):**
```
cd /opt/vmstation-org/cluster-setup/ansible
ansible-playbook -i inventory/hosts.yml -l masternode ../../cluster-config/ansible/playbooks/kerberos-setup.yml --tags server
ansible-playbook -i inventory/hosts.yml -l masternode ../../cluster-config/ansible/playbooks/keycloak-setup.yml
```
- Validate FreeIPA and Keycloak endpoints are reachable before proceeding.

**Troubleshooting:**
If you see `the role 'keycloak' was not found`, make sure you are running from the correct repo directory (where the intended `ansible.cfg` is located). This ensures Ansible uses the correct roles_path and settings for each phase.

## 2. Enforce Baseline OS Configuration
```
ansible-playbook -i vmstation-org/cluster-setup/ansible/inventory/hosts.yml playbooks/baseline-hardening.yml
```

## 3. Infrastructure Services
```
ansible-playbook -i vmstation-org/cluster-setup/ansible/inventory/hosts.yml playbooks/infrastructure-services.yml
```

## 4. Baseline Validation
```
./scripts/check-drift.sh
./scripts/gather-config.sh
ansible-playbook -i vmstation-org/cluster-setup/ansible/inventory/hosts.yml playbooks/preflight-checks.yml
```

## 5. Cluster Deployment
```
ansible-playbook -i vmstation-org/cluster-setup/ansible/inventory/hosts.yml playbooks/deploy-cluster.yml
```

## 6. Monitoring & Stack Deployment
```
ansible-playbook -i vmstation-org/cluster-setup/ansible/inventory/hosts.yml playbooks/deploy-monitoring-stack.yml
```

## 7. Integrate cert-manager with FreeIPA CA
- Configure cert-manager issuer to use FreeIPA CA
- Automate certificate requests for cluster workloads

## 8. Post-deploy Validation
- Validate cluster, monitoring, and SSO endpoints
- Run post-deploy scripts and document outputs


Canonical inventory location used in all commands:
`vmstation-org/cluster-setup/ansible/inventory/hosts.yml`

This sequence ensures all dependencies are satisfied and the stack is secure, maintainable, and ready for CI/CD automation.
