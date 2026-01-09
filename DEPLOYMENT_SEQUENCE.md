# IMPORTANT: Ensure the secret management script is executable before running the deployment script.
# If you see 'Permission denied' for apply-oauth2-proxy-secret.sh, run:
#   sudo chmod +x ../scripts/apply-oauth2-proxy-secret.sh
# VMStation Cluster Deployment Sequence

This file documents the recommended order and commands for deploying the full stack, including identity, baseline, infrastructure, cluster, and monitoring. Use this as a reference for manual operations or CI/CD pipeline automation.

## 0. Workspace Preparation
Clone all required organization repositories into `/opt/vmstation-org` on your deployment host:
```sh

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

```
This ensures all required codebases are present for subsequent steps.

## 1. Bootstrap Identity & SSO
**Important:**
For each deployment phase, always change directory (`cd`) into the relevant repo before running Ansible commands. This ensures the correct `ansible.cfg`, inventory, and roles are used for that phase.

**Example (Bootstrap Phase - Kubespray-first workflow):**
```sh
# Prepare and run Kubespray to perform host preparation and cluster bring-up (recommended for mixed OS clusters)
cd /opt/vmstation-org/cluster-infra
# Maintain a canonical Kubespray inventory in this repo (outside the Kubespray submodule):
# Copy the canonical inventory from `cluster-setup` to `cluster-infra/inventory/mycluster/hosts.yaml` if you need to refresh it,
# or edit `cluster-infra/inventory/mycluster/hosts.yaml` directly on the masternode.
# Then run Kubespray pointing to the external inventory file. This avoids modifying the Kubespray submodule itself.

cd /opt/vmstation-org/cluster-infra/kubespray
# Example: run Kubespray with the external inventory file
# Prerequisite: ensure the correct Ansible version is available before running
# (run these steps once per masternode or in CI prior to invoking the playbook)
```sh
# Use an isolated virtualenv and install ansible-core in the required range
python3 -m venv ~/.venv/kubespray-ansible
source ~/.venv/kubespray-ansible/bin/activate
python -m pip install --upgrade pip setuptools wheel
pip install "ansible-core>=2.17.3,<2.18.0"

# Install Kubespray Python requirements from the cloned repo
cd /opt/vmstation-org/cluster-infra/kubespray
pip install -r requirements.txt

# Verify ansible-playbook is the one from the venv
ansible-playbook --version

# Fail-fast: ensure ansible-core 2.17.x is active (helpful reminder to activate venv)
if ! ansible-playbook --version 2>/dev/null | grep -q -E 'core 2\.17'; then
	echo "ERROR: ansible-playbook does not appear to be ansible-core 2.17.x"
	echo "Activate the virtualenv and retry: source ~/.venv/kubespray-ansible/bin/activate"
	exit 1
fi

# Then run the Kubespray playbook (inside the activated venv)
ansible-playbook -i /opt/vmstation-org/cluster-infra/inventory/mycluster/hosts.yaml cluster.yml -b --become-user=root
```

<!-- Operational convenience: one-time clone + transient symlink example -->

```sh

# One-time: clone the official Kubespray repo (only needed once per masternode)
git clone https://github.com/kubernetes-sigs/kubespray.git /opt/vmstation-org/cluster-infra/kubespray

# Transient symlink approach (convenient, do NOT commit this symlink into the submodule)
mkdir -p /opt/vmstation-org/cluster-infra/kubespray/inventory
ln -s /opt/vmstation-org/cluster-infra/inventory/mycluster /opt/vmstation-org/cluster-infra/kubespray/inventory/mycluster

# Run Kubespray using the repo-local inventory path (then remove the symlink)
cd /opt/vmstation-org/cluster-infra/kubespray
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b --become-user=root
rm -f /opt/vmstation-org/cluster-infra/kubespray/inventory/mycluster
```

## 2. RHEL Registration & Repository Enablement (RHEL/Rocky/AlmaLinux nodes)

> **Important for RHEL-family nodes:**
> Before running baseline-hardening, you must register your RHEL system and enable required repositories. This ensures all dependencies (such as `htop` and `libhwloc.so.15`) are available. If these steps are skipped, the playbook will fail on RHEL nodes.

**Register your RHEL system:**
```sh
sudo subscription-manager register
# Enter your Red Hat credentials when prompted
```

**Enable required repositories:**
```sh
# Enable base, extras, and CodeReady Builder (for RHEL 8+)
sudo subscription-manager repos --enable "codeready-builder-for-rhel-8-$(arch)-rpms"
sudo dnf install -y epel-release
```

**If you encounter errors about missing `libhwloc.so.15` or `htop`:**
> - Ensure CodeReady Builder and EPEL are enabled.
> - You may need to manually install `libhwloc` or `htop` if not available via dnf.
> - See RHEL documentation for troubleshooting repository access.

---

## 3. Enforce Baseline OS Configuration

```sh
# Run from the `cluster-setup` repo root so its `ansible.cfg` and role paths are used
cd /opt/vmstation-org/cluster-setup
sudo ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/baseline-hardening.yml --become
```


<!-- First step is to create a password for keycloak services -->
```sh

sudo mkdir -p /opt/vmstation-org/cluster-infra/helm
sudo cp /opt/vmstation-org/cluster-infra/helm/keycloak-values.example.yaml /opt/vmstation-org/cluster-infra/helm/keycloak-values.yaml
sudo chown $(id -u):$(id -g) /opt/vmstation-org/cluster-infra/helm/keycloak-values.yaml
# Edit and replace placeholders (admin password, LDAP bind password, etc.)

cd /opt/vmstation-org/cluster-infra/ansible
# Usage
sudo ../scripts/cleanup-identity-stack.sh
sudo ansible-playbook -i /opt/vmstation-org/cluster-setup/ansible/inventory/hosts.yml playbooks/identity-deploy-and-handover.yml --become
	# \ -e identity_force_replace=true



```
Usages:

# Default behavior: auto-generate CA if needed
```sh
ansible-playbook ansible/playbooks/identity-deploy-and-handover.yml
```
# Disable CA auto-generation (requires manual CA provisioning)
```sh
ansible-playbook ansible/playbooks/identity-deploy-and-handover.yml -e identity_generate_ca=false
```
# Use existing CA files (place at /opt/vmstation-org/cluster-setup/scripts/certs/)
```sh
ansible-playbook ansible/playbooks/identity-deploy-and-handover.yml
```

Note: `enable_postgres_chown` is enabled by default. The playbook will attempt
to repair hostPath ownership for PostgreSQL during the replace flow, so you do
not normally need to pass `-e enable_postgres_chown=true` explicitly.

- Validate FreeIPA and Keycloak endpoints are reachable before proceeding.


<!-- COMPLETED DEPLOYMENT AND TESTING UPTO HERE -->


## 2. Enforce Baseline OS Configuration

> **Note for RHEL/Rocky/AlmaLinux nodes:**
> The baseline-hardening playbook installs `htop` as a base package. On some RHEL-family systems, `htop` requires the library `libhwloc.so.15` (or similar). If this library is not available in your enabled repositories, you may need to manually install it or enable the appropriate repository (such as EPEL or PowerTools) before running the playbook. If the dependency is missing, the playbook will fail on that node.

```sh
# Run from the `cluster-setup` repo root so its `ansible.cfg` and role paths are used
cd /opt/vmstation-org/cluster-setup
sudo ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/baseline-hardening.yml --become
```


## 3. Infrastructure Services
```sh
cd /opt/vmstation-org/cluster-setup
sudo ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/infrastructure-services.yml --become
```
note: Installed helm, and python 2.16 intepreter manually on the homelab node, unsure of what caused these issues.


## 4. Baseline Validation

```sh
cd /opt/vmstation-org/cluster-setup
./scripts/check-drift.sh
./scripts/gather-config.sh
sudo ansible-playbook -i ansible/inventory/hosts.yml playbooks/preflight-checks.yml --become
```

## 4a. Configure DNS Records and Network Ports for FreeIPA/Keycloak

**Before deploying infrastructure services, ensure the following:**

- **DNS Records:**
	- Add all records listed in `/tmp/ipa.system.records.*.db` from the FreeIPA pod to your DNS system.
		- Example:
			```sh
			sudo kubectl exec -n identity freeipa-0 -- cat /tmp/ipa.system.records.*.db
			```
	- Ensure `ipa.vmstation.local` and any other required hostnames resolve correctly from all cluster nodes and clients.

- **Firewall/Network Ports:**
	- The following ports must be open between cluster nodes, FreeIPA, Keycloak, and clients as appropriate:
		- **TCP:** 22 (SSH, must always be open), 80, 443 (HTTP/HTTPS), 389, 636 (LDAP/LDAPS), 88, 464 (Kerberos), 53 (DNS if used)
		- **UDP:** 88, 464 (Kerberos), 53 (DNS if used)
	- SSH (port 22) must remain open and unrestricted for all cluster nodes at all times.
	- If your baseline hardening or infrastructure playbooks manage firewall rules, ensure these ports are explicitly allowed.

- **FreeIPA/Keycloak Readiness:**
	- Confirm FreeIPA and Keycloak pods are READY (1/1) and running before proceeding.
	- Access the FreeIPA web UI at https://ipa.vmstation.local/ipa/ui to verify login works.
	- Optionally, test Kerberos with `kinit admin` from a client.


# Quick automated deployment
# Automated
```sh
cd /opt/vmstation-org/cluster-infra/ansible
sudo ansible-playbook -i /opt/vmstation-org/cluster-setup/ansible/inventory/hosts.yml /opt/vmstation-org/cluster-infra/ansible/playbooks/configure-coredns-freeipa.yml

# # Or run individual scripts
# ./scripts/extract-freeipa-dns-records.sh
# ./scripts/configure-dns-records.sh
# ./scripts/configure-network-ports.sh
# ./scripts/verify-freeipa-keycloak-readiness.sh

# # For testing ldap dir services requires exec into freeipa
# sudo apt update
# sudo apt install ldap-utils krb5-user

```


## 4b. Setup CoreDNS 
```sh
cd /opt/vmstation-org/cluster-infra

# Ensure kubelet is configured to use the CoreDNS service IP for cluster DNS:
# Edit /var/lib/kubelet/config.yaml on all nodes and set:
#
# clusterDNS:
#   - 10.233.0.10
#
# Then restart kubelet on each node:
#   sudo systemctl restart kubelet
#
# This ensures all pods use the correct CoreDNS service for DNS resolution.

ansible-playbook -i inventory/mycluster/hosts.yaml ansible/playbooks/configure-coredns-freeipa.yml




# New wrapper script consolidating 4a+5
sudo ./scripts/automate-identity-dns-and-coredns.sh --verbose --force-cleanup
```
## 4C. New wrapper script for 4a+4b+more
```sh
# Deploy only
sudo ./scripts/identity-full-deploy.sh

# Automated reset + deploy
sudo FORCE_RESET=1 RESET_CONFIRM=yes ./scripts/identity-full-deploy.sh

# Preview actions
sudo DRY_RUN=1 FORCE_RESET=1 ./scripts/identity-full-deploy.sh

# Custom credentials
sudo FREEIPA_ADMIN_PASSWORD=secret KEYCLOAK_ADMIN_PASSWORD=secret ./scripts/identity-full-deploy.sh



# Custom credentials with full reset

cd /opt/vmstation-org/cluster-infra
git pull origin main  # Pull latest script fixes from GitHub
chmod +x scripts/*.sh  # Ensure all scripts are executable

cd ansible

# OPTION 1: Using command-line arguments (RECOMMENDED - works with any sudo configuration)
sudo ../scripts/identity-full-deploy.sh --force-reset --reset-confirm

# OPTION 2: Using environment variables with sudo -E (requires sudo -E to preserve variables)
sudo -E FORCE_RESET=1 RESET_CONFIRM=yes FREEIPA_ADMIN_PASSWORD=secret123 KEYCLOAK_ADMIN_PASSWORD=secret123 ../scripts/identity-full-deploy.sh

# One-liner with git pull, chmod, and CLI arguments (RECOMMENDED):
cd /opt/vmstation-org/cluster-infra && \
git pull origin main && \
chmod +x scripts/*.sh && \
cd ansible && \
sudo FREEIPA_ADMIN_PASSWORD=secret123 KEYCLOAK_ADMIN_PASSWORD=secret123 ../scripts/identity-full-deploy.sh --force-reset --reset-confirm

# IMPORTANT: Ensure all scripts are executable before running the deployment script.
# If you see 'not found or not executable' errors, run:
#   chmod +x scripts/*.sh  (from cluster-infra directory)
#
# TROUBLESHOOTING: If you see "Client already exists" errors:
# - The keycloak-create-clients.sh script now handles existing clients gracefully (fixed 2026-01-09)
# - Ensure you've pulled the latest changes from the main branch
# - The script will now automatically extract secrets from existing clients
# - If you see "For input string: 'json'" errors, ensure you have the latest version (fixed 2026-01-09)
#
# TROUBLESHOOTING: If Keycloak SSO configuration fails with "Connection refused":
# - The script now waits up to 100 seconds (10 retries x 10s) for Keycloak to become ready after restart
# - Check Keycloak pod status: kubectl -n identity get pods -l app.kubernetes.io/name=keycloak
# - Check Keycloak logs: kubectl -n identity logs -l app.kubernetes.io/name=keycloak --tail=100
#
# TROUBLESHOOTING: If oauth2-proxy is in CrashLoopBackOff:
# - Fixed 2026-01-09: Shell argument parsing bug (double backslashes in YAML manifest)
# - Ensure you've pulled the latest changes: git pull origin main
# - Check oauth2-proxy logs: kubectl -n identity logs -l app=oauth2-proxy --tail=50
# - The pod should now start successfully with proper argument parsing
#
# TROUBLESHOOTING: If FreeIPA pod enters "Failed" state:
# - Fixed 2026-01-09: Improved liveness/readiness probes and added resource limits
# - Common causes:
#   1. OOMKilled - Pod ran out of memory (now has 2Gi-4Gi limits)
#   2. Liveness probe killing healthy pod (now more lenient with better logic)
#   3. FreeIPA install failure (check logs with diagnostic script)
# - Diagnostic script: sudo /opt/vmstation-org/cluster-infra/scripts/diagnose-freeipa-failure.sh
# - Manual checks:
#   kubectl -n identity describe pod freeipa-0  # Check events and conditions
#   kubectl -n identity logs freeipa-0 -c freeipa-server --tail=200  # Check logs
#   kubectl -n identity logs freeipa-0 -c freeipa-server --previous  # Check previous crash
# - The identity-service-accounts role now attempts automatic restart on failure
# - If FreeIPA repeatedly fails:
#   1. Check memory available on control-plane node: kubectl top nodes
#   2. Check storage permissions: ls -lah /srv/monitoring-data/freeipa/
#   3. Review manifest: /opt/vmstation-org/cluster-infra/manifests/identity/freeipa.yaml
#   4. Consider increasing memory limits if OOMKilled
# - FreeIPA requires at least 2Gi memory and can take 30+ minutes for first-time install


```


## 6. Monitoring & Stack Deployment

```sh

cd /opt/vmstation-org/cluster-monitor-stack

sudo ansible-playbook -i /opt/vmstation-org/cluster-setup/ansible/inventory/hosts.yml ansible/playbooks/preflight-monitoring.yaml --become

sudo ansible-playbook -i /opt/vmstation-org/cluster-setup/ansible/inventory/hosts.yml ansible/playbooks/deploy-monitoring-stack.yaml --become


sudo ansible-playbook -i /opt/vmstation-org/cluster-setup/ansible/inventory/hosts.yml ansible/playbooks/deploy-monitoring-stack.yaml --become -e keycloak_admin_user=admin -e keycloak_admin_password=secret123 -e keycloak_url='http://192.168.4.63:30180'

```
**Reminder:**
After deploying CoreDNS, monitoring, and cluster services, always validate that all identity and SSO endpoints are working:
- FreeIPA web UI and LDAP (https://ipa.vmstation.local/ipa/ui, ldap://ipa.vmstation.local)
- Keycloak web UI and SSO login
- Kerberos (kinit admin)
- Any other LDAP/SSO-integrated services

This ensures that DNS, authentication, and identity integrations are functional before moving to workload or application deployment.



## 7. Integrate cert-manager with FreeIPA CA
- Configure cert-manager issuer to use FreeIPA CA
- Automate certificate requests for cluster workloads

## 8. Post-deploy Validation
- Validate cluster, monitoring, and SSO endpoints
- Run post-deploy scripts and document outputs


Canonical inventory location - Source of Truth:
`vmstation-org/cluster-setup/ansible/inventory/hosts.yml`
Canonical kubespray inventory location used in kubespray commands: 
`/opt/vmstation-org/cluster-infra/inventory/mycluster/hosts.yaml`

This sequence ensures all dependencies are satisfied and the stack is secure, maintainable, and ready for CI/CD automation.



## 20. Cluster reset 


``` sh
cd /opt/vmstation-org/cluster-infra
sudo ansible-playbook -i /opt/vmstation-org/cluster-infra/inventory/mycluster/ ansible/playbooks/reset-cluster.yaml --become

# Optional
	-e reset_remove_containerd_state=true
```