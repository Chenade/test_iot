# Part 1 - K3s Multi-Node Cluster

## Overview

This part demonstrates how to set up a basic Kubernetes cluster using K3s with a server (master) node and a worker (agent) node. The setup uses Vagrant and VirtualBox to provision two virtual machines that communicate over a private network.

## Architecture

```
┌─────────────────────┐         ┌─────────────────────┐
│   Server Node       │         │   Worker Node       │
│  192.168.56.110     │◄────────┤  192.168.56.111     │
│                     │  Token  │                     │
│  K3s Server         │         │  K3s Agent          │
│  kubectl            │         │                     │
└─────────────────────┘         └─────────────────────┘
```

## Components

### Virtual Machines
- **Server Node**: Runs K3s in server mode (control plane)
  - Hostname: `{USER}S` (e.g., `vagrantS`)
  - IP: 192.168.56.110
  - Memory: 1024 MB
  - CPUs: 1

- **Worker Node**: Runs K3s in agent mode
  - Hostname: `{USER}SW` (e.g., `vagrantSW`)
  - IP: 192.168.56.111
  - Memory: 1024 MB
  - CPUs: 1

### K3s Configuration
- **Network Interface**: eth1 (Flannel CNI)
- **Kubeconfig Mode**: 644 (readable by all users)
- **API Port**: 6443

## Directory Structure

```
p1/
├── Vagrantfile           # VM configuration
├── conf/
│   └── conf.yaml        # Configuration file for VMs and K3s
├── scripts/
│   ├── server.sh        # Provisioning script for server node
│   └── agent.sh         # Provisioning script for worker node
└── token/               # Created during provisioning
    └── node-token       # K3s token for agent authentication
```

## Setup Instructions

### Prerequisites
- VirtualBox installed
- Vagrant installed
- At least 2GB of free RAM
- Internet connection for downloading K3s

### Installation

1. Navigate to the p1 directory:
```bash
cd p1
```

2. Start the virtual machines:
```bash
vagrant up
```

This command will:
- Create two VMs (server and worker)
- Install K3s on the server node
- Copy the node token to a shared directory
- Install K3s agent on the worker node
- Join the worker to the server

3. Verify the cluster is running:
```bash
vagrant ssh {USER}S
sudo kubectl get nodes
```

Expected output:
```
NAME        STATUS   ROLES                  AGE   VERSION
{USER}s     Ready    control-plane,master   Xm    vX.XX.X+k3s1
{USER}sw    Ready    <none>                 Xm    vX.XX.X+k3s1
```

## Configuration Details

### conf.yaml
The configuration file contains all customizable parameters:

```yaml
local_user: vagrant              # Default user
vm_provider: virtualbox          # Virtualization provider
vm_box: bento/debian-12.6       # Base box image
vm_mem: 1024                    # Memory allocation (MB)
vm_cpu_count: 1                 # Number of CPUs
vm_time_out: 600                # Boot timeout (seconds)
server_ip: 192.168.56.110       # Server node IP
server_script: scripts/server.sh # Server provisioning script
worker_ip: 192.168.56.111       # Worker node IP
worker_script: scripts/agent.sh  # Worker provisioning script
kub_port: 6443                  # Kubernetes API port
```

### server.sh Script
The server provisioning script performs the following:
1. Creates kubectl alias: `k='sudo kubectl'`
2. Updates system packages
3. Installs K3s in server mode with:
   - Flannel network interface on eth1
   - Node IP set to server_ip
   - Kubeconfig with 644 permissions
4. Copies node token to shared `/vagrant/token` directory

### agent.sh Script
The worker provisioning script performs the following:
1. Updates system packages
2. Installs K3s in agent mode with:
   - Connection to server at KUB_URL
   - Authentication using shared token file
   - Flannel network interface on eth1
   - Node IP set to worker_ip

## Usage

### Access Server Node
```bash
vagrant ssh {USER}S
```

### Access Worker Node
```bash
vagrant ssh {USER}SW
```

### Run kubectl Commands
On the server node:
```bash
# Using full command
sudo kubectl get nodes
sudo kubectl get pods -A

# Using alias (if configured in .bashrc)
k get nodes
k get pods -A
```

### Stop Virtual Machines
```bash
vagrant halt
```

### Destroy Virtual Machines
```bash
vagrant destroy -f
```

## Troubleshooting

### Issue: VMs fail to start
**Solution**:
- Check VirtualBox is installed and running
- Verify virtualization is enabled in BIOS
- Ensure no port conflicts with existing VMs

### Issue: Worker node doesn't join the cluster
**Solution**:
- Verify the token file exists at `/vagrant/token/node-token`
- Check network connectivity between nodes:
  ```bash
  vagrant ssh {USER}SW
  ping 192.168.56.110
  ```
- Review K3s agent logs:
  ```bash
  sudo journalctl -u k3s-agent -f
  ```

### Issue: kubectl commands fail
**Solution**:
- Ensure you're on the server node
- Use sudo: `sudo kubectl get nodes`
- Check K3s is running: `sudo systemctl status k3s`

### Issue: Network connectivity problems
**Solution**:
- Verify both VMs have the private network interface:
  ```bash
  ip addr show eth1
  ```
- Check Flannel is running:
  ```bash
  sudo kubectl get pods -n kube-system | grep flannel
  ```

## Subject Requirements Checklist

This part must meet the following requirements from the subject:

- [ ] 2 machines running with Vagrant
- [ ] Latest stable version of chosen distribution
- [ ] Minimal resources: 1 CPU and 512MB-1024MB RAM
- [ ] Machine names: `{login}S` (Server) and `{login}SW` (ServerWorker)
- [ ] Server IP: 192.168.56.110
- [ ] ServerWorker IP: 192.168.56.111
- [ ] SSH connection with no password required
- [ ] K3s installed in controller mode on Server
- [ ] K3s installed in agent mode on ServerWorker
- [ ] kubectl installed and functional
- [ ] Configuration files in `confs/` folder
- [ ] Scripts in `scripts/` folder

## Key Concepts

### What is K3s?

**K3s** is a lightweight, certified Kubernetes distribution built for IoT and edge computing. Created by Rancher Labs (now part of SUSE), it is designed to be:

- **Lightweight**: Single binary under 100MB (compared to standard Kubernetes which requires multiple components)
- **Simple**: Easy to install and maintain with minimal dependencies
- **Secure**: Secure by default with reasonable defaults for production workloads
- **Production-ready**: Fully conformant Kubernetes distribution, certified by CNCF
- **Resource-efficient**: Runs well on ARM devices and systems with limited resources

**Key differences from standard Kubernetes:**
- Packaged as a single binary
- Uses SQLite as the default datastore (instead of etcd)
- Includes built-in components: Traefik (Ingress), CoreDNS, Flannel (CNI)
- Automatic TLS certificate management
- Optimized for edge and IoT deployments

### Server vs Agent (Controller vs Worker)

**Server Mode (Controller)**:
- Runs the complete Kubernetes control plane
- Components include:
  - API Server: Entry point for all REST commands
  - Scheduler: Assigns pods to nodes
  - Controller Manager: Runs controller processes
  - Cloud Controller Manager (optional)
- Stores cluster state in embedded database (SQLite or etcd)
- Can also run workloads (unlike dedicated control plane nodes)

**Agent Mode (Worker)**:
- Runs only the worker components
- Components include:
  - Kubelet: Manages containers on the node
  - Container Runtime: Runs containers (containerd)
  - Kube-proxy: Maintains network rules
- Connects to the server using a node token
- Receives instructions from the control plane

### Node Token

The **node token** is a secret authentication credential used to:
- Authenticate agent nodes when joining the cluster
- Secure communication between server and agents
- Prevent unauthorized nodes from joining

**How it works:**
1. Server generates token during installation
2. Token stored at `/var/lib/rancher/k3s/server/node-token`
3. Agent uses token to authenticate with server API
4. Server validates token and accepts node into cluster

**Security note**: Keep the token secret! Anyone with the token can add nodes to your cluster.

### Flannel (CNI)

**Flannel** is a Container Network Interface (CNI) plugin that:
- Provides Layer 3 network fabric for containers
- Assigns subnet to each node in the cluster
- Enables pod-to-pod communication across nodes
- Uses VXLAN encapsulation by default

**Why specify `--flannel-iface=eth1`?**
- K3s needs to know which network interface to use
- eth1 is the private network interface created by Vagrant
- Ensures cluster traffic uses the correct network (192.168.56.x)
- Without this, K3s might use the wrong interface (NAT interface)

## Frequently Asked Questions (Subject Q&A)

**Q: What is K3s?**
A: K3s is a lightweight, CNCF-certified Kubernetes distribution designed for IoT, edge computing, and resource-constrained environments. It packages Kubernetes and its dependencies into a single binary under 100MB, making it easy to install and maintain while providing full Kubernetes functionality.

**Q: Why use two machines instead of one?**
A: This demonstrates a real-world Kubernetes architecture with separate control plane (server) and worker nodes. It teaches you about cluster networking, node communication, and the distributed nature of Kubernetes.

**Q: What is the purpose of the node token?**
A: The node token authenticates worker nodes when they join the cluster, ensuring only authorized nodes can become part of your Kubernetes cluster. It's a security mechanism to prevent rogue nodes from joining.

**Q: Why is SSH without password required?**
A: This is automatically configured by Vagrant using SSH key-based authentication, which is more secure than password authentication and required for automation and ease of access during development.

**Q: Can I use a different IP range?**
A: While technically possible, the subject specifically requires 192.168.56.110 and 192.168.56.111 to ensure consistency during evaluation. These IPs are in the VirtualBox host-only network range.

## Next Steps

After completing Part 1, you can:
1. Verify cluster status: `sudo kubectl get nodes`
2. Deploy a test application to verify the cluster works
3. Explore Kubernetes resources (deployments, services, pods)
4. Move on to Part 2 to learn about Ingress and application deployment

## Important Notes for Defense

During your evaluation, be prepared to:
- Demonstrate `vagrant up` creating both machines
- Show both nodes in the cluster: `sudo kubectl get nodes`
- Verify network configuration: `ip a show eth1` on both machines
- Explain the difference between server and agent modes
- Show the node token file location
- SSH into both machines
- Run kubectl commands on the server node
