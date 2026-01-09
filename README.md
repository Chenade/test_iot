# Inception-of-Things [42 Project]
> Summary: This project is designed to help you discover Kubernetes through setting up K3s and K3d clusters, deploying applications, and implementing GitOps practices with ArgoCD.

## Project Overview

Inception-of-Things (IoT) is a DevOps project that introduces you to Kubernetes fundamentals, infrastructure automation, and continuous deployment. Through three progressive parts, you'll learn to set up lightweight Kubernetes distributions and implement modern deployment practices.

## Prerequisites

- VirtualBox 6.1+
- Vagrant 2.2+
- kubectl (for P3)
- Docker (for P3)
- k3d (for P3)

## Project Structure

```
.
├── p1/          # Part 1: K3s cluster with server and worker nodes
├── p2/          # Part 2: K3s with multiple applications and Ingress
└── p3/          # Part 3: K3d with ArgoCD for GitOps
```

## Skills Demonstrated

- Kubernetes cluster setup and management (K3s, K3d)
- Virtual machine provisioning with Vagrant and VirtualBox
- Kubernetes resource management (Deployments, Services, Ingress)
- GitOps practices with ArgoCD
- Container orchestration and networking
- Infrastructure as Code (IaC)
- Continuous deployment automation
- Service mesh and load balancing

## Parts Summary

### Part 1 - K3s Multi-Node Cluster
**Objective**: Set up a basic K3s cluster with one server and one worker node

**Key Components**:
- Two VMs: Server (192.168.56.110) and Worker (192.168.56.111)
- K3s lightweight Kubernetes distribution
- Private network configuration
- Node token sharing between VMs

**Setup**:
```bash
cd p1
vagrant up
```

---

### Part 2 - K3s with Ingress and Multiple Applications
**Objective**: Deploy three web applications with Ingress-based routing

**Key Components**:
- Single server node running K3s
- Three replicated applications (app1, app2, app3)
- Ingress controller for host-based routing
- Custom domain mapping (app1.com, app2.com, app3.com)

**Features**:
- app1: 1 replica
- app2: 3 replicas (load-balanced)
- app3: 1 replica
- Host-based routing via Ingress

**Setup**:
```bash
cd p2
vagrant up

# Option A: Configure /etc/hosts (requires sudo)
sudo sh -c 'echo "192.168.56.110 app1.com app2.com app3.com" >> /etc/hosts'

# Option B: Use curl with Host headers (no sudo needed)
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110  # app3 (default)
```

---

### Part 3 - K3d with ArgoCD (GitOps)
**Objective**: Implement continuous deployment with ArgoCD

**Key Components**:
- K3d cluster (Kubernetes in Docker)
- ArgoCD for GitOps-based deployment
- Automated sync from Git repository
- Application deployed in dev namespace

**Features**:
- Automated installation of Docker, kubectl, k3d
- ArgoCD installation and configuration
- Self-healing and automated pruning
- Git repository as single source of truth

**Setup**:
```bash
cd p3
# Install prerequisites (Docker, kubectl, k3d)
./scripts/prereq.sh

# Setup cluster and ArgoCD
./scripts/setup.sh

# Access ArgoCD UI at localhost:8080
# Username: admin
# Password: admin123
```

## Usage Notes

### Part 1 & 2 (Vagrant-based)
- Use `vagrant up` to create and provision VMs
- Use `vagrant ssh <vm-name>` to access VMs
- Use `vagrant halt` to stop VMs
- Use `vagrant destroy` to remove VMs
- Configuration is managed via YAML files in `conf/` or `confs/` directories

### Part 3 (K3d-based)
- Runs directly on host machine (no VMs)
- Requires Docker to be running
- Cluster name: `mycluster`
- ArgoCD manages deployments automatically from Git

## Project Structure

According to the subject requirements, configuration files should be organized as follows:
- **P1**: `p1/confs/` - Configuration files (Note: currently using `conf/`)
- **P2**: `p2/confs/` - Configuration files
- **P3**: `p3/confs/` - Configuration files (Note: currently using `conf/`)
- Scripts should be in `scripts/` folders

Each part uses configuration files to customize the setup:
- **P1**: VM and network settings, K3s installation scripts
- **P2**: VM configuration, Kubernetes manifests (Deployments, Services, Ingress)
- **P3**: Kubernetes manifests, ArgoCD application definitions, installation scripts

## Troubleshooting

### Common Issues

**Vagrant fails to start VMs**:
- Ensure VirtualBox is installed and running
- Check if virtualization is enabled in BIOS

**Vagrant tries to use libvirt instead of VirtualBox**:
- If you see "Error while connecting to Libvirt", run:
  ```bash
  vagrant up --provider=virtualbox
  ```
- Or uninstall vagrant-libvirt: `vagrant plugin uninstall vagrant-libvirt`
- The Vagrantfiles have been updated to explicitly use VirtualBox

**Connection Refused (ERR_CONNECTION_REFUSED) - Part 2**:
- Most common: Traefik (Ingress) needs 30-60 seconds to start - wait and retry
- Check Traefik is running: `vagrant ssh yangchiS -c "sudo kubectl get pods -n kube-system | grep traefik"`
- Test from inside VM: `vagrant ssh yangchiS -c "curl http://192.168.56.110"`
- Check network: `ping 192.168.56.110`
- See detailed troubleshooting in p2/README.md

**K3s installation fails**:
- Verify network connectivity
- Check available disk space and memory

**ArgoCD sync fails**:
- Verify Git repository URL in `argo-application.yaml`
- Check ArgoCD has access to the repository
- Review ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`

**Ingress not working**:
- Verify `/etc/hosts` entries for custom domains
- Check Ingress controller is running: `kubectl get pods -A | grep ingress`

## Learning Resources

- [K3s Documentation](https://docs.k3s.io/)
- [K3d Documentation](https://k3d.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Vagrant Documentation](https://www.vagrantup.com/docs)

## Project Requirements

This project is part of the 42 curriculum and demonstrates:
- Understanding of Kubernetes architecture
- Ability to set up and manage clusters
- Knowledge of container orchestration
- GitOps and continuous deployment practices
- Infrastructure automation skills
