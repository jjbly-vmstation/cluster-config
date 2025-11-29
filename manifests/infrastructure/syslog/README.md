# Syslog Infrastructure Manifests

This directory contains Kubernetes manifests for syslog-related configurations.

## Contents

- `configmap.yaml` - ConfigMap containing rsyslog configuration

## Usage

Apply the syslog configuration:

```bash
kubectl apply -f manifests/infrastructure/syslog/
```

## Architecture

1. **Syslog Server (masternode)**
   - Receives logs from all cluster nodes
   - Stores logs in `/var/log/remote/<hostname>/`
   - Manages log rotation and retention

2. **Syslog Clients (all nodes)**
   - Forward logs to central syslog server
   - Maintain local log copies
   - Queue logs during network issues

## Notes

- Syslog is primarily configured at the host level via Ansible
- These manifests are for containerized workloads that need syslog forwarding
- Consider using Kubernetes-native logging (Loki, ELK) for production
