# Part 2 - K3s with Ingress and Multiple Applications

## Overview

This part demonstrates deploying multiple web applications on a single K3s server node with Ingress-based routing. You'll learn how to configure host-based routing to direct traffic to different applications based on domain names.

## Architecture

```
                      ┌──────────────────────┐
                      │  Server Node         │
                      │  192.168.56.110      │
                      │                      │
                      │  ┌────────────────┐  │
     app1.com ────────┼─►│    Ingress     │  │
                      │  │  Controller    │  │
     app2.com ────────┼─►│                │  │
                      │  └────────┬───────┘  │
     app3.com ────────┼───────────┘          │
  (or any other)      │           │          │
                      │  ┌────────▼───────┐  │
                      │  │   app1-service │  │
                      │  │   (1 replica)  │  │
                      │  └────────────────┘  │
                      │  ┌────────────────┐  │
                      │  │   app2-service │  │
                      │  │   (3 replicas) │  │
                      │  └────────────────┘  │
                      │  ┌────────────────┐  │
                      │  │   app3-service │  │
                      │  │   (1 replica)  │  │
                      │  └────────────────┘  │
                      └──────────────────────┘
```

## Components

### Virtual Machine
- **Server Node**: Single K3s server
  - Hostname: `{USER}S` (e.g., `vagrantS`)
  - IP: 192.168.56.110
  - Memory: 2048 MB
  - CPUs: 2

### Applications
- **app1**: Hello Kubernetes application
  - 1 replica
  - Accessible at: app1.com
  - Message: "This is app1"

- **app2**: Hello Kubernetes application
  - 3 replicas (load-balanced)
  - Accessible at: app2.com
  - Message: "This is app2"

- **app3**: Hello Kubernetes application (default)
  - 1 replica
  - Accessible at: app3.com or any other domain
  - Message: "This is app3"

### Ingress Controller
- Uses K3s built-in Traefik Ingress controller
- Host-based routing configuration
- app3 configured as default backend (catches all unmatched hosts)

## Directory Structure

```
p2/
├── Vagrantfile              # VM configuration
├── confs/
│   ├── vars.yaml           # Configuration file for VM
│   ├── deployment.yaml     # Kubernetes Deployments for all apps
│   ├── service.yaml        # Kubernetes Services for all apps
│   └── ingress.yaml        # Ingress routing rules
├── scripts/
│   └── server.sh           # Provisioning script
└── token/                  # Created during provisioning
    └── node-token          # K3s node token
```

## Setup Instructions

### Prerequisites
- VirtualBox installed
- Vagrant installed
- At least 2GB of free RAM
- Internet connection

### Installation

1. Navigate to the p2 directory:
```bash
cd p2
```

2. Start the virtual machine:
```bash
vagrant up
```

This command will:
- Create a VM with K3s server
- Install additional tools (curl, vim, net-tools)
- Configure /etc/hosts for domain resolution
- Apply Kubernetes manifests (deployments, services, ingress)

3. Configure your host machine's /etc/hosts file:

**Option A: Using /etc/hosts (requires sudo):**
```bash
# On your host machine (not inside the VM)
sudo sh -c 'echo "192.168.56.110 app1.com" >> /etc/hosts'
sudo sh -c 'echo "192.168.56.110 app2.com" >> /etc/hosts'
sudo sh -c 'echo "192.168.56.110 app3.com" >> /etc/hosts'
```

**Option B: Without sudo access (alternative methods):**

If you don't have sudo access on your host machine, you can use these alternatives:

**Method 1: Using curl with Host headers (Best for testing/defense):**
```bash
# Test app1
curl -H "Host: app1.com" http://192.168.56.110

# Test app2
curl -H "Host: app2.com" http://192.168.56.110

# Test app3 (or just use IP directly)
curl http://192.168.56.110
```

**Method 2: Browser extension for Host header modification:**

Install a browser extension to modify HTTP headers:

- **Chrome/Edge**: [ModHeader](https://chrome.google.com/webstore/detail/modheader/idgpnmonknjnojddfkpgkljpfnnfcklj)
- **Firefox**: [Modify Header Value](https://addons.mozilla.org/en-US/firefox/addon/modify-header-value/)

Configure the extension to add a custom header:
- Header Name: `Host`
- Header Value: `app1.com` (change to `app2.com` or `app3.com` as needed)
- Target URL: `http://192.168.56.110`

Then visit `http://192.168.56.110` in your browser, and the extension will make it appear as `app1.com` to the Ingress controller.

**Method 3: Access default backend directly:**
```bash
# app3 is the default backend, so just visit the IP
http://192.168.56.110
```

4. Verify the applications are running:
```bash
vagrant ssh {USER}S
sudo kubectl get pods
sudo kubectl get services
sudo kubectl get ingress
```

5. Access the applications from your browser:
- http://app1.com
- http://app2.com
- http://app3.com

## Configuration Details

### vars.yaml
```yaml
local_user: vagrant              # Default user
vm_provider: virtualbox          # Virtualization provider
vm_box: bento/debian-12.6       # Base box image
vm_mem: 2048                    # Memory allocation (2GB)
vm_cpu_count: 2                 # Number of CPUs
vm_time_out: 600                # Boot timeout
server_ip: 192.168.56.110       # Server node IP
server_script: scripts/server.sh # Provisioning script
kub_port: 6443                  # Kubernetes API port
```

### How Vagrant Provisioning Works

Understanding the automation flow from `vagrant up` to script execution:

```
vagrant up
  ↓
Reads Vagrantfile
  ↓
Loads confs/vars.yaml
  ↓ server_script = "scripts/server.sh"
  ↓ server_ip = "192.168.56.110"
  ↓
Creates VM "yangchiS"
  ↓
Provisions VM with:
  → Run: scripts/server.sh
  → As: root (privileged: true)
  → With: SERVER_IP=192.168.56.110 (environment variable)
```

**Key Vagrantfile line (line 72):**
```ruby
server.vm.provision "shell", privileged: true, path: server_script, env: { "SERVER_IP" => server_ip }
```

**What this means:**
- `provision "shell"` → Execute a shell script during VM setup
- `privileged: true` → Run as root (with sudo)
- `path: server_script` → Use the script from vars.yaml (`scripts/server.sh`)
- `env: { "SERVER_IP" => server_ip }` → Pass SERVER_IP as environment variable

**When does provisioning run?**
- ✅ First `vagrant up` (initial creation)
- ✅ `vagrant provision` (force re-provision)
- ✅ `vagrant reload --provision` (restart + provision)
- ❌ `vagrant halt` then `vagrant up` (unless you add `--provision`)

**What server.sh does:**
1. Sets up kubectl alias
2. Updates system packages
3. Installs K3s in server mode
4. Saves node token to `/vagrant/token`
5. Configures /etc/hosts **inside the VM** (for internal testing)
6. Applies Kubernetes manifests (deployments, services, ingress)

### deployment.yaml
Defines three Kubernetes Deployments:
- **app1-deployment**: 1 replica of hello-kubernetes:1.10.1
- **app2-deployment**: 3 replicas of hello-kubernetes:1.10.1
- **app3-deployment**: 1 replica of hello-kubernetes:1.10.1

Each deployment uses environment variables to customize the displayed message.

### service.yaml
Defines three Kubernetes Services:
- **app1-service**: ClusterIP service, port 80 → 8080
- **app2-service**: ClusterIP service, port 80 → 8080
- **app3-service**: ClusterIP service, port 80 → 8080

Services provide stable endpoints for the deployments.

### ingress.yaml
Defines Ingress routing rules:
- **app1.com** → routes to app1-service
- **app2.com** → routes to app2-service
- **Default route** (no host specified) → routes to app3-service

The default route catches all requests that don't match app1.com or app2.com, effectively routing app3.com and any other domain to app3.

### server.sh Script
Provisioning steps:
1. Creates kubectl alias
2. Updates system packages
3. Installs curl, vim, net-tools
4. Installs K3s server
5. Saves node token
6. Configures /etc/hosts for domain resolution
7. Applies Kubernetes manifests

## Usage

### Access the Server
```bash
vagrant ssh {USER}S
```

### View Running Pods
```bash
sudo kubectl get pods
```

Expected output:
```
NAME                               READY   STATUS    RESTARTS   AGE
app1-deployment-xxxxx-xxxxx        1/1     Running   0          Xm
app2-deployment-xxxxx-xxxxx        1/1     Running   0          Xm
app2-deployment-xxxxx-xxxxx        1/1     Running   0          Xm
app2-deployment-xxxxx-xxxxx        1/1     Running   0          Xm
app3-deployment-xxxxx-xxxxx        1/1     Running   0          Xm
```

### View Services
```bash
sudo kubectl get services
```

### View Ingress Configuration
```bash
sudo kubectl get ingress
sudo kubectl describe ingress ingress-of-things
```

### Test Load Balancing (app2)
Since app2 has 3 replicas, refreshing the page at http://app2.com will show requests being distributed across different pods:
```bash
# From your terminal
curl http://app2.com
```

### Stop the Virtual Machine
```bash
vagrant halt
```

### Destroy the Virtual Machine
```bash
vagrant destroy -f
```

## Troubleshooting

### Issue: Vagrant tries to use libvirt instead of VirtualBox
**Error**: `Error while connecting to Libvirt`

**Solution**:
```bash
vagrant up --provider=virtualbox
```

Or uninstall the vagrant-libvirt plugin:
```bash
vagrant plugin uninstall vagrant-libvirt
```

### Issue: Connection Refused (ERR_CONNECTION_REFUSED)
**Error**: Browser shows "192.168.56.110 refused to connect" or `ERR_CONNECTION_REFUSED`

**Common Causes & Solutions:**

1. **Traefik still starting up (most common)**
   - Traefik (Ingress Controller) needs 30-60 seconds to fully start after `vagrant up`
   - **Solution**: Wait 1-2 minutes and try again

   Check if Traefik is ready:
   ```bash
   vagrant ssh yangchiS
   sudo kubectl get pods -n kube-system | grep traefik
   # Wait until traefik pod shows 1/1 Running
   ```

2. **Verify everything is running**
   ```bash
   # Check VM is running
   vagrant status

   # Check pods are running
   vagrant ssh yangchiS -c "sudo kubectl get pods"
   # All pods should show Running

   # Check Ingress is configured
   vagrant ssh yangchiS -c "sudo kubectl get ingress"
   # Should show ADDRESS: 192.168.56.110

   # Check Traefik service
   vagrant ssh yangchiS -c "sudo kubectl get svc -A | grep traefik"
   # Should show LoadBalancer with 192.168.56.110
   ```

3. **Test from inside the VM first**
   ```bash
   vagrant ssh yangchiS
   curl http://192.168.56.110
   # Should return HTML from app3 (default backend)
   ```

   If this works but your browser doesn't, it's a host-to-VM networking issue.

4. **Check network connectivity**
   ```bash
   # From your host machine
   ping 192.168.56.110
   # Should get responses
   ```

   If ping fails:
   - Check VirtualBox Host-Only network adapter is enabled
   - On Linux: Check vboxnet0 interface exists: `ip a | grep vboxnet`
   - Restart the VM: `vagrant reload`

5. **Firewall blocking connections**
   ```bash
   # On Linux, check if firewall is blocking
   sudo iptables -L | grep 192.168.56

   # Temporarily disable firewall to test (Ubuntu/Debian)
   sudo ufw status
   sudo ufw allow from 192.168.56.0/24
   ```

6. **VM network interface not configured**
   ```bash
   vagrant ssh yangchiS -c "ip a show eth1"
   # Should show eth1 with IP 192.168.56.110
   ```

   If eth1 is missing or has wrong IP:
   ```bash
   vagrant reload
   ```

### Issue: Cannot access app1.com, app2.com, or app3.com
**Solution**:
- Verify /etc/hosts entries on your host machine:
  ```bash
  cat /etc/hosts | grep app
  ```
- Ensure entries point to 192.168.56.110
- Try accessing by IP: http://192.168.56.110

### Issue: Pods are not running
**Solution**:
- Check pod status:
  ```bash
  sudo kubectl get pods
  sudo kubectl describe pod <pod-name>
  ```
- View pod logs:
  ```bash
  sudo kubectl logs <pod-name>
  ```

### Issue: Ingress not routing correctly
**Solution**:
- Verify Ingress controller is running:
  ```bash
  sudo kubectl get pods -n kube-system | grep traefik
  ```
- Check Ingress configuration:
  ```bash
  sudo kubectl describe ingress ingress-of-things
  ```
- Verify services are accessible:
  ```bash
  sudo kubectl get endpoints
  ```

### Issue: app3 doesn't work with custom domains
**Solution**:
This is expected behavior! app3 is configured as the default backend. It will respond to:
- http://app3.com (explicitly added to /etc/hosts)
- Any other domain pointing to 192.168.56.110
- Direct IP access: http://192.168.56.110

### Issue: Image pull errors
**Solution**:
- Check internet connectivity from VM:
  ```bash
  vagrant ssh {USER}S
  ping 8.8.8.8
  ```
- Verify Docker Hub is accessible
- Check K3s can pull images:
  ```bash
  sudo crictl pull paulbouwer/hello-kubernetes:1.10.1
  ```

## Subject Requirements Checklist

This part must meet the following requirements from the subject:

- [ ] 1 virtual machine with Vagrant
- [ ] K3s in server mode only (no worker node)
- [ ] 3 web applications running
- [ ] Host-based routing configured
- [ ] Server IP: 192.168.56.110
- [ ] Machine name: `{login}S`
- [ ] app1.com → displays app1
- [ ] app2.com → displays app2 (with 3 replicas)
- [ ] Default route → displays app3
- [ ] Ingress configuration visible during defense
- [ ] Configuration files in `confs/` folder
- [ ] Scripts in `scripts/` folder

## Key Concepts

### What is an Ingress?

**Ingress** is a Kubernetes API object that manages external HTTP/HTTPS access to services within a cluster. It acts as an intelligent router that sits at the edge of your cluster.

**Key features:**
- **Host-based routing**: Route traffic based on domain names (app1.com vs app2.com)
- **Path-based routing**: Route based on URL paths (/api vs /web)
- **TLS/SSL termination**: Handle HTTPS certificates at the edge
- **Load balancing**: Distribute traffic across multiple pod replicas
- **Single entry point**: One IP address for multiple services

**Analogy**: Think of Ingress as a receptionist in a building. When visitors (HTTP requests) arrive, the receptionist (Ingress) checks who they're looking for (hostname/path) and directs them to the correct office (service/pod).

**Why use Ingress instead of NodePort or LoadBalancer?**
- Saves resources (one IP for many services vs one IP per service)
- Provides advanced routing capabilities
- Centralized TLS certificate management
- More cost-effective in cloud environments

### Ingress Controller

An **Ingress Controller** is the actual implementation that fulfills the Ingress rules. It's the worker that does what the Ingress configuration specifies.

**K3s includes Traefik by default**, which:
- Implements the Ingress rules automatically
- Acts as a reverse proxy
- Handles incoming HTTP/HTTPS traffic
- Routes requests to appropriate services
- Provides automatic service discovery
- Includes metrics and monitoring

**How it works:**
1. You create an Ingress resource with routing rules
2. Ingress Controller watches for Ingress resources
3. Controller configures itself based on the rules
4. Traffic arrives at the controller
5. Controller routes to the correct service
6. Service forwards to appropriate pods

**Alternative Ingress Controllers:**
- NGINX Ingress Controller
- HAProxy
- Istio Gateway
- Ambassador

### Service Types

This setup uses **ClusterIP services** (Kubernetes default):

**ClusterIP** characteristics:
- Internal-only IP address within the cluster
- Not accessible from outside the cluster
- Accessible only through Ingress or port-forwarding
- Most common type for web applications behind Ingress
- Provides stable internal endpoint for pods

**Other service types (not used here):**
- **NodePort**: Exposes service on each node's IP at a static port
- **LoadBalancer**: Provisions an external load balancer (cloud only)
- **ExternalName**: Maps service to a DNS name

### Replica Sets and High Availability

**app2 demonstrates horizontal scaling with 3 replicas:**

**Benefits:**
- **High availability**: If one pod dies, others continue serving traffic
- **Load distribution**: Traffic spread across multiple pods
- **Zero-downtime updates**: Rolling updates possible with multiple replicas
- **Performance**: Parallel processing of requests

**How it works:**
1. Deployment specifies `replicas: 3`
2. Kubernetes creates 3 identical pods
3. Service load-balances across all 3 pods
4. If a pod fails, Kubernetes automatically replaces it
5. During updates, Kubernetes gradually replaces old pods with new ones

**You can test this:**
```bash
# Delete one pod
kubectl delete pod <app2-pod-name>

# Service keeps working (traffic goes to other pods)
curl http://app2.com

# Watch Kubernetes recreate the pod
kubectl get pods --watch
```

### Default Backend

The Ingress configuration makes **app3 the default backend** by omitting the `host` field in one rule:

```yaml
- http:  # No host specified!
    paths:
    - path: /
      backend:
        service:
          name: app3-service
```

**This means:**
- Requests to app1.com → app1-service
- Requests to app2.com → app2-service
- Requests to ANY other domain → app3-service (default)
- Direct IP access (192.168.56.110) → app3-service

**Why have a default backend?**
- Handles unmatched requests gracefully
- Can show a "catch-all" page
- Useful for maintenance pages or redirects
- Prevents errors for typos in domain names

### Host-based Routing

**Host-based routing** uses the HTTP `Host` header to route traffic:

**HTTP Request anatomy:**
```
GET / HTTP/1.1
Host: app1.com          ← This header determines the route
User-Agent: curl/7.68.0
```

**How routing works:**
1. Browser sends request to 192.168.56.110
2. Request includes `Host: app1.com` header
3. Traefik (Ingress Controller) receives request
4. Traefik checks Ingress rules for matching host
5. Finds rule: app1.com → app1-service
6. Forwards request to app1-service
7. Service routes to one of app1's pods
8. Pod returns response

**This requires `/etc/hosts` configuration:**
```
192.168.56.110 app1.com
192.168.56.110 app2.com
192.168.56.110 app3.com
```

Without this, your browser wouldn't know where to send requests for these domains.

## Frequently Asked Questions (Subject Q&A)

**Q: What is an Ingress?**
A: An Ingress is a Kubernetes API object that provides HTTP/HTTPS routing to services within the cluster. It enables host-based and path-based routing, allowing multiple applications to share a single IP address and providing a centralized entry point for external traffic.

**Q: Why do we need only one VM for this part?**
A: Part 2 focuses on application deployment and Ingress configuration, not cluster architecture. A single K3s server can run both the control plane and workloads, which is sufficient for learning about Ingress and multi-application deployments.

**Q: How does the Ingress know which app to route to?**
A: The Ingress Controller (Traefik) reads the `Host` header from incoming HTTP requests and matches it against the rules defined in the Ingress resource. When a match is found, traffic is routed to the corresponding service.

**Q: Why does app2 need 3 replicas specifically?**
A: The subject specifies 3 replicas for app2 to demonstrate load balancing and high availability concepts. It shows that Kubernetes can manage multiple instances of the same application and distribute traffic among them automatically.

**Q: What happens if I don't configure /etc/hosts?**
A: Without /etc/hosts entries, your browser won't know that app1.com, app2.com, and app3.com should resolve to 192.168.56.110. However, you have excellent alternatives:
  - Use curl with Host headers: `curl -H "Host: app1.com" http://192.168.56.110`
  - Use a browser extension like ModHeader to set custom Host headers
  - Access app3 directly via IP (it's the default backend): `http://192.168.56.110`

  The curl method is actually preferred for defense as it clearly demonstrates your understanding of how Ingress routing works!

**Q: Can I use different application images?**
A: Yes! The subject says "web applications of your choice." You can use any containerized web application. The paulbouwer/hello-kubernetes image is just a simple example that displays the pod name and custom messages.

**Q: Must I show the Ingress during defense?**
A: Yes! The subject explicitly states "The Ingress is not displayed here on purpose. You will have to show it to your evaluators during your defense." Be prepared to run `kubectl get ingress` and `kubectl describe ingress`.

## Testing Scenarios

### Test 1: Verify each application is accessible
```bash
curl http://app1.com
curl http://app2.com
curl http://app3.com
```

### Test 2: Verify default backend
```bash
curl http://anything-else.com  # Should show app3
curl http://192.168.56.110     # Should show app3
```

### Test 3: Verify app2 load balancing
```bash
# Multiple requests should hit different pods
for i in {1..10}; do curl -s http://app2.com | grep "Pod Name"; done
```

### Test 4: Test high availability
```bash
# Delete one app2 pod and verify traffic still works
sudo kubectl delete pod <app2-pod-name>
curl http://app2.com  # Should still work
```

## Important Notes for Defense

During your evaluation, be prepared to:

1. **Show the VM starting:**
   ```bash
   vagrant up
   ```

2. **Display all running pods:**
   ```bash
   sudo kubectl get pods
   # Should show: 1 app1 pod, 3 app2 pods, 1 app3 pod
   ```

3. **Display the Ingress (REQUIRED):**
   ```bash
   sudo kubectl get ingress
   sudo kubectl describe ingress ingress-of-things
   ```

4. **Show the services:**
   ```bash
   sudo kubectl get services
   ```

5. **Access each application:**

   **If you have /etc/hosts configured:**
   - Browser: http://app1.com
   - Browser: http://app2.com
   - Browser: http://app3.com

   **If you DON'T have sudo access (alternative - actually better for demonstrating understanding):**
   ```bash
   # Show app1
   curl -H "Host: app1.com" http://192.168.56.110

   # Show app2
   curl -H "Host: app2.com" http://192.168.56.110

   # Show app3 (default)
   curl http://192.168.56.110

   # Demonstrate app2 load balancing across 3 replicas
   for i in {1..10}; do curl -s -H "Host: app2.com" http://192.168.56.110 | grep -i "pod\|app2"; done
   ```

6. **Demonstrate default backend:**
   - http://192.168.56.110 (should show app3)
   - This works because app3 is configured as the default backend

7. **Explain the architecture:**
   - How Ingress routes traffic
   - Why app2 has 3 replicas
   - What happens with unmatched hosts

8. **Show configuration files:**
   - deployment.yaml (3 deployments)
   - service.yaml (3 services)
   - ingress.yaml (routing rules)

## Next Steps

After completing Part 2, you should:
1. Ensure all pods are running and accessible
2. Verify Ingress routing works correctly
3. Test load balancing with app2's 3 replicas
4. Move on to Part 3 to learn about GitOps with ArgoCD
