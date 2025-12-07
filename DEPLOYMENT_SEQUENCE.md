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

Playbook run took 0 days, 0 hours, 0 minutes, 0 seconds
Sunday 07 December 2025  15:20:42 -0500 (0:00:00.063)       0:00:00.180 *******
===============================================================================
Display FreeIPA installation instructions ----------------------------------------------------------------------------------------------------------- 0.06s
Install FreeIPA server packages --------------------------------------------------------------------------------------------------------------------- 0.04s
Check if FreeIPA is already installed --------------------------------------------------------------------------------------------------------------- 0.04s
[WARNING]: Invalid characters were found in group names but not replaced, use -vvvv to see details

PLAY [Bootstrap Keycloak SSO] ******************************************************************************************************************************

TASK [keycloak : Pull Keycloak container image] ************************************************************************************************************
Sunday 07 December 2025  15:20:43 -0500 (0:00:00.031)       0:00:00.031 *******
ok: [masternode]

TASK [keycloak : Run Keycloak container] *******************************************************************************************************************
Sunday 07 December 2025  15:21:27 -0500 (0:00:44.287)       0:00:44.319 *******
fatal: [masternode]: FAILED! => changed=false
  cmd:
  - ctr
  - run
  - --detach
  - --rm
  - --name
  - keycloak-server
  - -p
  - 8080:8080
  - quay.io/keycloak/keycloak:latest
  - /opt/keycloak/bin/kc.sh
  - start-dev
  delta: '0:00:00.014094'
  end: '2025-12-07 15:21:27.884947'
  msg: non-zero return code
  rc: 1
  start: '2025-12-07 15:21:27.870853'
  stderr: 'ctr: flag provided but not defined: -name'
  stderr_lines: <omitted>
  stdout: |-
    Incorrect Usage: flag provided but not defined: -name

    NAME:
       ctr run - Run a container

    USAGE:
       ctr run [command options] [flags] Image|RootFS ID [COMMAND] [ARG...]

    OPTIONS:
       --rm                                    Remove the container after running, cannot be used with --detach
       --null-io                               Send all IO to /dev/null
       --log-uri value                         Log uri
       --detach, -d                            Detach from the task after it has started execution, cannot be used with --rm
       --fifo-dir value                        Directory used for storing IO FIFOs
       --cgroup value                          Cgroup path (To disable use of cgroup, set to "" explicitly)
       --platform value                        Run image for specific platform
       --cni                                   Enable cni networking for the container
       --runc-binary value                     Specify runc-compatible binary
       --runc-root value                       Specify runc-compatible root
       --runc-systemd-cgroup                   Start runc with systemd cgroup manager
       --uidmap container-uid:host-uid:length  Run inside a user namespace with the specified UID mapping range; specified with the format container-uid:host-uid:length
       --gidmap container-gid:host-gid:length  Run inside a user namespace with the specified GID mapping range; specified with the format container-gid:host-gid:length
       --remap-labels                          Provide the user namespace ID remapping to the snapshotter via label options; requires snapshotter support
       --privileged-without-host-devices       Don't pass all host devices to privileged container
       --cpus value                            Set the CFS cpu quota (default: 0)
       --cpu-shares value                      Set the cpu shares (default: 1024)
       --snapshotter value                     Snapshotter name. Empty value stands for the default value. [$CONTAINERD_SNAPSHOTTER]
       --snapshotter-label value               Labels added to the new snapshot for this container.
       --config value, -c value                Path to the runtime-specific spec config file
       --cwd value                             Specify the working directory of the process
       --env value                             Specify additional container environment variables (e.g. FOO=bar)
       --env-file value                        Specify additional container environment variables in a file(e.g. FOO=bar, one per line)
       --label value                           Specify additional labels (e.g. foo=bar)
       --annotation value                      Specify additional OCI annotations (e.g. foo=bar)
       --mount value                           Specify additional container mount (e.g. type=bind,src=/tmp,dst=/host,options=rbind:ro)
       --net-host                              Enable host networking for the container
       --privileged                            Run privileged container
       --read-only                             Set the containers filesystem as readonly
       --runtime value                         Runtime name or absolute path to runtime binary (default: "io.containerd.runc.v2")
       --sandbox value                         Create the container in the given sandbox
       --runtime-config-path value             Optional runtime config path
       --tty, -t                               Allocate a TTY for the container
       --with-ns value                         Specify existing Linux namespaces to join at container runtime (format '<nstype>:<path>')
       --pid-file value                        File path to write the task's pid
       --gpus value                            Add gpus to the container
       --allow-new-privs                       Turn off OCI spec's NoNewPrivileges feature flag
       --memory-limit value                    Memory limit (in bytes) for the container (default: 0)
       --cap-add value                         Add Linux capabilities (Set capabilities with 'CAP_' prefix)
       --cap-drop value                        Drop Linux capabilities (Set capabilities with 'CAP_' prefix)
       --seccomp                               Enable the default seccomp profile
       --seccomp-profile value                 File path to custom seccomp profile. seccomp must be set to true, before using seccomp-profile
       --apparmor-default-profile value        Enable AppArmor with the default profile with the specified name, e.g. "cri-containerd.apparmor.d"
       --apparmor-profile value                Enable AppArmor with an existing custom profile
       --blockio-config-file value             File path to blockio class definitions. By default class definitions are not loaded.
       --blockio-class value                   Name of the blockio class to associate the container with
       --rdt-class value                       Name of the RDT class to associate the container with. Specifies a Class of Service (CLOS) for cache and memory bandwidth management.
       --hostname value                        Set the container's host name
       --user value, -u value                  Username or user id, group optional (format: <name|uid>[:<group|gid>])
       --rootfs                                Use custom rootfs that is not managed by containerd snapshotter
       --no-pivot                              Disable use of pivot-root (linux only)
       --cpu-quota value                       Limit CPU CFS quota (default: -1)
       --cpu-period value                      Limit CPU CFS period (default: 0)
       --rootfs-propagation value              Set the propagation of the container rootfs
       --device value                          File path to a device to add to the container; or a path to a directory tree of devices to add to the container
  stdout_lines: <omitted>
        to retry, use: --limit @/tmp/ansible_retry/keycloak-setup.retry

PLAY RECAP *************************************************************************************************************************************************
masternode                 : ok=1    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0

Playbook run took 0 days, 0 hours, 0 minutes, 44 seconds
Sunday 07 December 2025  15:21:27 -0500 (0:00:00.220)       0:00:44.540 *******
===============================================================================
keycloak : Pull Keycloak container image ----------------------------------------------------------------------------------------------------------- 44.29s
keycloak : Run Keycloak container ------------------------------------------------------------------------------------------------------------------- 0.22s

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
