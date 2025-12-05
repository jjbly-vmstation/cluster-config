# Ansible SSH Key Requirements

All managed nodes must be accessible via SSH using the correct private key as specified in the inventory (e.g., ~/.ssh/id_k3s for worker nodes).

- Ensure the SSH private key exists and is accessible by the Ansible control user.
- For each node, verify the `ansible_ssh_private_key_file` path in the inventory is correct.
- If you encounter SSH errors, copy the correct private key to the control node and set permissions to 600.

Example:
```
chmod 600 ~/.ssh/id_k3s
```

This is required for successful Ansible playbook execution across all nodes.
