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


## 2. Enforce Baseline OS Configuration
```sh
# Run from the `cluster-setup` repo root so its `ansible.cfg` and role paths are used
cd /opt/vmstation-org/cluster-setup
sudo ansible-playbook -i ansible/inventory/hosts.yml playbooks/baseline-hardening.yml --become
```


## 3. Infrastructure Services
```sh
cd /opt/vmstation-org/cluster-setup
sudo ansible-playbook -i ansible/inventory/hosts.yml playbooks/infrastructure-services.yml --become
```

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
			kubectl exec -n identity freeipa-0 -- cat /tmp/ipa.system.records.*.db
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

---

Continue with infrastructure services deployment after these checks.

## 5. Cluster Deployment
```sh
cd /opt/vmstation-org/cluster-setup
sudo ansible-playbook -i ansible/inventory/hosts.yml playbooks/deploy-cluster.yml --become
```

## 6. Monitoring & Stack Deployment
```sh
cd /opt/vmstation-org/cluster-setup
sudo ansible-playbook -i ansible/inventory/hosts.yml playbooks/deploy-monitoring-stack.yml --become
```

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