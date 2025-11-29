# NTP Infrastructure Manifests

This directory contains Kubernetes manifests for NTP-related configurations.

## Contents

- `configmap.yaml` - ConfigMap containing chrony configuration

## Usage

Apply the NTP configuration:

```bash
kubectl apply -f manifests/infrastructure/ntp/
```

## Notes

- The NTP configuration is primarily managed at the host level via Ansible
- These manifests are for pods that may need their own NTP configuration
- Most Kubernetes workloads rely on the host's time synchronization
