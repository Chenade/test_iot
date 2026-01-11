# Part 3 - K3d with ArgoCD (GitOps)

## Overview

This part demonstrates GitOps practices using K3d (Kubernetes in Docker) and ArgoCD. You'll learn how to implement continuous deployment where your Git repository serves as the single source of truth for your application deployments.

## Quick Start

```bash
# Complete setup (one command!)
make

# Or step by step:
make install   # Install prerequisites (Docker, k3d, kubectl)
make setup     # Create cluster and deploy ArgoCD
make app       # Start auto-reconnecting port-forward

# Access services:
# ArgoCD UI:    https://localhost:8080 (admin/admin123)
# Application:  http://localhost:8888
```

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Host Machine                                   │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │  K3d Cluster (Docker Container)           │ │
│  │                                           │ │
│  │  ┌─────────────────────────────────────┐ │ │
│  │  │  ArgoCD Namespace                   │ │ │
│  │  │  - ArgoCD Server                    │ │ │
│  │  │  - Application Controller           │ │ │
│  │  │  - Repo Server                      │ │ │
│  │  └─────────────┬───────────────────────┘ │ │
│  │                │ monitors                │ │
│  │                ▼                         │ │
│  │  ┌─────────────────────────────────────┐ │ │
│  │  │  Dev Namespace                      │ │ │
│  │  │  - wil-playground Deployment        │ │ │
│  │  │  - wil-playground Service           │ │ │
│  │  └─────────────────────────────────────┘ │ │
│  │                ▲                         │ │
│  │                │ syncs from              │ │
│  │                │                         │ │
│  └────────────────┼─────────────────────────┘ │
│                   │                           │
└───────────────────┼───────────────────────────┘
                    │
                    ▼
          ┌──────────────────┐
          │  Git Repository  │
          │  (GitHub)        │
          └──────────────────┘
```

## Components

### K3d Cluster
- **Name**: mycluster
- **Nodes**: 1 server
- **Runtime**: Docker containers
- **Distribution**: K3s (lightweight Kubernetes)

### ArgoCD
- **Namespace**: argocd
- **Components**:
  - Application Controller: Monitors applications and compares live state with Git
  - Repo Server: Fetches manifests from Git repositories
  - Server: Provides API and UI
  - Redis: Caching and queuing
  - Dex: SSO/OIDC authentication (optional)

### Application
- **Name**: wil-playground-app
- **Namespace**: dev
- **Image**: wil42/playground:v1
- **Port**: 8888
- **Replicas**: 1

### ArgoCD Configuration
- **Auto-sync**: Enabled
- **Self-heal**: Enabled (automatically fixes drift)
- **Prune**: Enabled (removes resources not in Git)
- **Sync Interval**: 30 seconds (checks GitHub every 30s)
- **Git Repository**: https://github.com/Chenade/test_iot

## Directory Structure

```
p3/
├── Makefile                    # Automation commands
├── confs/                      # Kubernetes manifests
│   ├── deployment.yaml         # Application deployment manifest
│   ├── service.yaml           # Application service manifest
│   └── argo-application.yaml  # ArgoCD Application resource
└── scripts/                    # Automation scripts
    ├── prereq.sh              # Prerequisites installation script
    ├── setup.sh               # Cluster and ArgoCD setup script
    └── watch-app.sh           # Auto-reconnecting port-forward script
```

## Makefile Targets

The project includes a comprehensive Makefile for easy management:

| Command | Description |
|---------|-------------|
| `make` or `make all` | Complete setup (install + setup) |
| `make install` | Install prerequisites (Docker, k3d, kubectl) |
| `make setup` | Create cluster, deploy ArgoCD, start port-forwards |
| `make status` | Show cluster info, pods, and application status |
| `make ui` | Start ArgoCD UI port-forward (8080) |
| `make app` | Start auto-reconnecting app port-forward (8888) |
| `make pods` | Show all pods in all namespaces |
| `make clean` | Delete the K3d cluster |
| `make fclean` | Clean cluster and remove cached prerequisites |
| `make re` | Full reset (fclean + setup) |
| `make help` | Show all available commands |

## Setup Instructions

```bash
cd p3
make
```

This single command will:
1. Install all prerequisites (Docker, k3d, kubectl)
2. Create K3d cluster "mycluster"
3. Deploy ArgoCD (configured for 30s sync interval)
4. Change ArgoCD password to `admin123`
5. Deploy wil-playground application
6. Start port-forwards for UI (8080) and app (8888)
7. Show cluster status

### Access Information

**ArgoCD UI:**
- URL: `https://localhost:8080`
- Username: `admin`
- Password: `admin123`

**Application:**
- URL: `http://localhost:8888`
- Returns: `{"status":"ok", "message": "v1"}`

## Configuration Details

**Environment Variables**:
- `NAMESPACE_ARGOCD`: argocd
- `NAMESPACE_DEV`: dev

### deployment.yaml

Defines a Kubernetes Deployment:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wil-playground
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wil-playground
  template:
    spec:
      containers:
      - name: wil-playground
        image: wil42/playground:v1
        ports:
        - containerPort: 8888
```

### service.yaml

Defines a Kubernetes Service to expose the application.

### argo-application.yaml

Defines an ArgoCD Application resource:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: wil-playground-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: "https://github.com/Chenade/test_iot.git"
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Key Fields**:
- `repoURL`: Git repository containing manifests
- `targetRevision`: Git branch/tag (main)
- `path`: Directory in repo containing manifests (. = root)
- `selfHeal`: Auto-fix drift from desired state
- `prune`: Auto-delete resources not in Git
- `syncOptions`: Additional sync options (CreateNamespace)
- `retry`: Retry policy for failed syncs (exponential backoff)


### Demonstrating GitOps (Version Change)

**Scenario**: Change from v1 to v2
   ```
```bash

# 1. Check current version
curl http://localhost:8888/
# Output: {"status":"ok", "message": "v1"}

# 2. Edit deployment.yaml in GitHub (v1 → v2)
# 3. Push to GitHub
# 4. Wait 30-60 seconds
# 5. Show ArgoCD auto-syncing in UI

# 6.Verify new version: curl http://localhost:8888/
curl http://localhost:8888/
# Output: {"status":"ok", "message": "v2"}
```

---

## Troubleshooting

### Issue: Docker permission denied
**Solution**:
```bash
# Add user to docker group (done by prereq.sh)
sudo usermod -aG docker $USER

# Logout and login again, or run:
newgrp docker

# Test:
docker ps
```

### Issue: ArgoCD pods not starting
**Solution**:
```bash
# Check pod status
kubectl get pods -n argocd

# View pod logs
kubectl logs -n argocd <pod-name>/home/yangchi/Project/42_Inception-of-things/p3

# Check events
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Common fix: wait longer or restart
kubectl rollout restart deployment -n argocd
```

### Issue: Cannot access ArgoCD UI
**Solution**:
```bash
# Verify port-forward is running
ps aux | grep port-forward

# Restart port-forward
killall kubectl
kubectl port-forward svc/argocd-server --address 0.0.0.0 -n argocd 8080:443 &

# Try accessing: http://localhost:8080
# Or try: http://127.0.0.1:8080
```

### Issue: Application stuck in "OutOfSync"
**Solution**:
```bash
# Check application status
argocd app get wil-playground-app

# View sync status
kubectl describe application wil-playground-app -n argocd

# Force sync
argocd app sync wil-playground-app --force

# Check if Git repo is accessible
argocd repo list
```

### Issue: Application not syncing automatically
**Solution**:
```bash
# Verify sync policy
kubectl get application wil-playground-app -n argocd -o yaml | grep -A 5 syncPolicy

# Enable auto-sync if needed
argocd app set wil-playground-app --sync-policy automated

# Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Issue: Port 8080 already in use
**Solution**:
```bash
# Find process using port 8080
sudo lsof -i :8080

# Kill the process or use a different port
kubectl port-forward svc/argocd-server --address 0.0.0.0 -n argocd 8081:443 &
```

### Issue: K3d cluster won't start
**Solution**:
```bash
# Check Docker is running
sudo systemctl status docker
sudo systemctl start docker

# Delete and recreate cluster
k3d cluster delete mycluster
k3d cluster create mycluster --servers 1

# Check logs
k3d cluster list
docker ps -a | grep k3d
```
---

## Key Concepts

### What is K3d?

**K3d** (K3s in Docker) is a lightweight wrapper that runs K3s clusters inside Docker containers.

**Key features:**
- **Fast**: Cluster creation in seconds (vs minutes with VMs)
- **Lightweight**: No VM overhead, runs directly in Docker
- **Easy cleanup**: Delete cluster = delete containers
- **Multi-cluster**: Run multiple clusters on one machine
- **Local development**: Perfect for testing and development
- **CI/CD friendly**: Fast setup for automated testing

**Architecture:**
```
┌─────────────────────────────────────┐
│  Host Machine                       │
│  ┌───────────────────────────────┐  │
│  │  Docker                       │  │
│  │  ┌─────────────────────────┐  │  │
│  │  │  K3s Container          │  │  │
│  │  │  (Full Kubernetes)      │  │  │
│  │  └─────────────────────────┘  │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

**Common commands:**
```bash
k3d cluster create mycluster  # Create cluster
k3d cluster list             # List clusters
k3d cluster delete mycluster # Delete cluster
```

### What is the difference between K3s and K3d?

This is a critical question that will likely be asked during your defense!

| Aspect | K3s | K3d |
|--------|-----|-----|
| **What it is** | Lightweight Kubernetes distribution | Wrapper to run K3s in Docker |
| **Runs on** | Bare metal, VMs, IoT devices | Docker containers |
| **Installation** | Binary or script on host OS | Docker image |
| **Startup time** | 1-2 minutes | Seconds |
| **Use case** | Production, edge, IoT | Development, testing, CI/CD |
| **Resource overhead** | Low (no VM) | Very low (containers) |
| **Cleanup** | Uninstall from OS | Delete container |
| **Multi-cluster** | One per machine/VM | Multiple per machine |
| **Persistence** | Persists after reboot | Can be ephemeral |

**Analogy:**
- **K3s** is like installing software directly on your computer
- **K3d** is like running that software in a virtual container

**When to use each:**
- **Use K3s** for: Production servers, edge devices, Raspberry Pi, VMs (like Parts 1 & 2)
- **Use K3d** for: Local development, CI/CD pipelines, testing, quick experiments (like Part 3)

### What is Argo CD?

**Argo CD** is a declarative, GitOps continuous delivery tool for Kubernetes.

**Core principle**: Your Git repository is the single source of truth for your application state.

**How it works:**
1. You define your application's desired state in Git (YAML manifests)
2. Argo CD monitors your Git repository
3. When you push changes, Argo CD detects them
4. Argo CD automatically applies changes to your cluster
5. If someone manually changes the cluster, Argo CD reverts it (self-heal)

**Key features:**
- **Automated deployment**: Push to Git → automatic deployment
- **Visual UI**: See all applications and their sync status
- **Rollback**: Easy revert to previous versions
- **Multi-cluster**: Manage multiple clusters from one Argo CD
- **RBAC**: Role-based access control
- **SSO integration**: Enterprise authentication

**Why use Argo CD?**
- **Audit trail**: Git history shows who changed what and when
- **Consistency**: Same deployment process for all environments
- **Disaster recovery**: Entire cluster state in Git
- **Collaboration**: Use Git workflows (PRs, reviews)
- **No kubectl needed**: Developers push to Git, not to cluster

### GitOps

**GitOps** is a paradigm where Git is the single source of truth for declarative infrastructure and applications.

**Core principles:**
1. **Declarative**: Describe the desired state, not the steps
2. **Versioned**: All changes tracked in Git
3. **Immutable**: Don't modify running systems, replace them
4. **Pulled automatically**: System pulls from Git, not pushed to

**Benefits:**
- **Version control**: All changes tracked in Git
- **Audit trail**: Who changed what and when
- **Easy rollback**: `git revert` to undo changes
- **Automated deployments**: Push to Git = deployed
- **Consistency**: Same state across environments
- **Collaboration**: Use familiar Git workflows

**Traditional deployment vs GitOps:**

**Traditional:**
```
Developer → kubectl apply → Cluster
```
- Manual steps
- No history
- Hard to replicate
- Error-prone

**GitOps:**
```
Developer → Git push → Argo CD → Cluster
```
- Automated
- Full history in Git
- Reproducible
- Self-documenting

### Self-Healing

**Self-healing** automatically corrects drift between Git state and live state.

**Example scenario:**
1. Your Git repo says: `replicas: 3`
2. Someone runs: `kubectl scale deployment myapp --replicas=5`
3. Cluster now has 5 replicas (drift from Git)
4. Argo CD detects the difference
5. Argo CD automatically changes back to 3 replicas
6. Cluster matches Git again

**Configuration in your Application:**
```yaml
syncPolicy:
  automated:
    selfHeal: true  # Enable self-healing
```

**Why is this useful?**
- Prevents manual changes from breaking production
- Ensures Git is always the source of truth
- Automatically fixes configuration drift
- Maintains consistency across clusters

### Automated Pruning

**Pruning** automatically removes resources that are deleted from Git.

**Example scenario:**
1. Your Git repo has: deployment.yaml, service.yaml, configmap.yaml
2. You delete configmap.yaml from Git
3. You push to Git
4. Argo CD syncs
5. Argo CD automatically deletes the ConfigMap from the cluster

**Configuration:**
```yaml
syncPolicy:
  automated:
    prune: true  # Enable pruning
```

**Without pruning:**
- Deleted files stay in the cluster
- Orphaned resources accumulate
- Manual cleanup required

**With pruning:**
- Git and cluster stay perfectly in sync
- No orphaned resources
- Clean and predictable

### Application Resource (CRD)

**ArgoCD Application** is a Custom Resource Definition (CRD) that represents a deployed application.

**Key fields:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app              # Application name
  namespace: argocd         # Must be in argocd namespace
spec:
  project: default          # Project (for RBAC)

  source:                   # WHERE to get manifests
    repoURL: "https://..."  # Git repository
    targetRevision: HEAD    # Branch/tag/commit
    path: ./manifests       # Directory in repo

  destination:              # WHERE to deploy
    server: https://...     # Kubernetes cluster API
    namespace: dev          # Target namespace

  syncPolicy:               # HOW to sync
    automated:
      selfHeal: true        # Auto-fix drift
      prune: true           # Auto-delete removed resources
```

**This is your deployment contract**: It tells Argo CD exactly what to deploy, where to deploy it, and how to keep it in sync.

### Continuous Integration vs Continuous Deployment

**Continuous Integration (CI):**
- Automatically build and test code
- Run on every commit/PR
- Ensure code quality
- Examples: GitHub Actions, Jenkins, GitLab CI

**Continuous Deployment (CD):**
- Automatically deploy tested code
- Deploy to production without manual intervention
- ArgoCD is a CD tool
- Comes after CI

**In this project:**
- You manually change the version in Git (v1 → v2)
- ArgoCD automatically deploys the change (CD)
- For full CI/CD, you'd add automated tests before deployment

## Frequently Asked Questions (Subject Q&A)

**Q: What is K3d?**
A: K3d is a lightweight wrapper that runs K3s (lightweight Kubernetes) clusters inside Docker containers. It enables fast cluster creation for local development and testing without the overhead of virtual machines.

**Q: What is the difference between K3s and K3d?**
A: K3s is a lightweight Kubernetes distribution that runs on bare metal, VMs, or IoT devices. K3d is a tool that runs K3s inside Docker containers, making it faster to create/destroy clusters and ideal for development. Think of K3d as "K3s in Docker."

**Q: What is Argo CD?**
A: Argo CD is a declarative GitOps continuous delivery tool for Kubernetes. It automatically deploys applications from Git repositories to Kubernetes clusters, monitors for changes, and keeps the cluster state synchronized with Git (the single source of truth).

**Q: Why use K3d instead of Vagrant for this part?**
A: K3d is faster (clusters in seconds vs minutes), lighter (no VM overhead), easier to clean up (just delete containers), and more suited for modern development workflows and CI/CD pipelines. It also introduces you to container-based Kubernetes, which is becoming the standard for local development.

**Q: Why do we need Docker for K3d?**
A: K3d runs K3s inside Docker containers. Each K3s node (server or agent) is a Docker container, so Docker must be installed and running for K3d to work.

**Q: What's the purpose of the two namespaces?**
A: The `argocd` namespace contains Argo CD itself (the controller, UI, and other components). The `dev` namespace contains your application that Argo CD deploys. This separation follows the pattern of keeping deployment tools separate from deployed applications.

**Q: How does Argo CD know when Git changes?**
A: In this setup, Argo CD polls the Git repository every 30 seconds (configured during setup). The default is 3 minutes, but we've optimized it for faster demonstration. You can also configure webhooks for instant notification of changes, or manually trigger a sync.

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [K3d Documentation](https://k3d.io/)
- [GitOps Principles](https://www.gitops.tech/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
