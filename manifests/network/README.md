# Network Manifests

This directory contains Kubernetes network configuration manifests.

## Contents

Network configurations for the VMStation cluster.

## Cluster Network Configuration

### Pod Network
- CIDR: `10.244.0.0/16`
- CNI: Flannel or Calico

### Service Network
- CIDR: `10.96.0.0/12`

### Node Network
- Subnet: `192.168.4.0/24`
- Gateway: `192.168.4.1`

## Nodes

| Node | IP Address | Role |
|------|------------|------|
| masternode | 192.168.4.63 | Control Plane |
| storagenodet3500 | 192.168.4.61 | Worker (Storage) |
| homelab | 192.168.4.62 | Worker (Compute) |

## DNS

Default DNS servers:
- `192.168.4.1` (local gateway)
- `8.8.8.8` (Google)
- `1.1.1.1` (Cloudflare)

## Notes

- Network configuration is primarily managed at the host level
- CNI configurations depend on the Kubernetes distribution
- See cluster-infra repository for advanced network policies
