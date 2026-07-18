# Walkthrough: Lima VM Setup for Sandbox and Development

We have created the configuration template for your native Lima VM setup. This environment satisfies all your requirements for flexible directory mounting, bidirectional networking, and graphical application forwarding.

## Files Created

- [lima/agent.yaml](file:///home/patrick/dotfiles/lima/agent.yaml): The main configuration file containing the VM setup, directory share definitions, port forwarding rules, and GUI forwarding enabling settings.

---

## Guide to Using the VM

### 1. Starting the VM
To create and boot the VM instance using this configuration, run the following command on the host:
```bash
limactl start lima/agent.yaml
```
During the prompt, select to start with the provided configuration. This will boot an Arch Linux virtual machine and automatically run the provisioning script to install `xorg-xauth`, `waypipe`, and GUI utilities inside the guest.

### 2. File Sharing & Directory Configuration
The directories shared between host and guest are defined under the `mounts` key in [lima/agent.yaml](file:///home/patrick/dotfiles/lima/agent.yaml):

```yaml
mounts:
  # Writable workspace mount
  - location: "~/workspace"
    writable: true

  # Writable dotfiles mount
  - location: "~/dotfiles"
    writable: true

  # Writable agents directory mount
  - location: "~/.agents"
    writable: true
```

If you need to change which directories are shared, or modify their read/write status:
1. Open [lima/agent.yaml](file:///home/patrick/dotfiles/lima/agent.yaml) and add or update locations in the `mounts` array.
2. Edit the active configuration with:
   ```bash
   limactl edit agent
   ```
3. Restart the VM to apply changes (this updates configuration mounts without recreating the VM):
   ```bash
   limactl stop agent && limactl start agent
   ```

### 3. Bidirectional Networking
- **Host-to-Guest**:
  By default, all TCP ports in the guest VM are forwarded to `127.0.0.1` on the host. If you run a service (e.g. on port `8000`) inside the guest, you can access it on the host via `http://localhost:8000`.
- **Guest-to-Host**:
  If a service is running on the host (e.g. port `9000`), the guest can talk to it using the special address `host.lima.internal`:
  ```bash
  curl http://host.lima.internal:9000
  ```

### 4. Running Graphical Applications
Both X11 and Wayland GUI applications are supported 

