# Kerberos Infrastructure Manifests

This directory contains Kubernetes manifests for Kerberos-related configurations.

## Contents

- `configmap.yaml` - ConfigMap containing krb5.conf

## Usage

Apply the Kerberos configuration:

```bash
kubectl apply -f manifests/infrastructure/kerberos/
```

## Prerequisites

Before using Kerberos:

1. **Time Synchronization**
   - Kerberos requires accurate time (within 5 minutes)
   - Ensure NTP is configured on all nodes

2. **DNS Configuration**
   - Proper hostname resolution is required
   - Consider using DNS SRV records for service discovery

3. **FreeIPA Server (Optional)**
   - For full identity management
   - Requires dedicated server deployment

## Notes

- Kerberos configuration is optional
- Primary use case is single sign-on (SSO)
- Most homelab setups work fine without Kerberos
