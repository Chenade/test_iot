CLUSTER_NAME = mycluster
NAMESPACE_ARGOCD = argocd
NAMESPACE_DEV = dev

# Setup K3d cluster and ArgoCD
setup: install
	@echo "Setting up K3d cluster and ArgoCD..."
	@chmod +x scripts/setup.sh
	@./scripts/setup.sh
	@echo "Setup complete."
	@echo ""
	@echo "✅ ArgoCD password has been set to: admin123"
	@echo ""
	make ui
	@echo ""
	@echo "Starting port-forward for application (background)..."
	@-pkill -9 -f "kubectl port-forward.*8888" 2>/dev/null || true
	@sleep 2
	@(kubectl port-forward -n $(NAMESPACE_DEV) svc/wil-playground-service 8888:8888 >> /tmp/app-pf.log 2>&1 &)
	@sleep 3
	@echo "✅ Application accessible at: http://localhost:8888"
	@echo ""
	@echo "Note: Port-forward started in background. Run 'make app' for auto-reconnecting version."
	@echo ""
	make status

# Install prerequisites (Docker, kubectl, k3d) - only run if not already done
.prereq_done:
	@echo "Installing prerequisites..."
	@chmod +x scripts/prereq.sh
	@./scripts/prereq.sh
	@touch .prereq_done

install: .prereq_done

# Port-forward ArgoCD UI
ui:
	@echo "Checking for existing port-forward on 8080..."
	@-pkill -9 -f "kubectl port-forward.*8080" 2>/dev/null || true
	@sleep 1
	@echo "Starting port-forward for ArgoCD UI..."
	@(kubectl port-forward svc/argocd-server --address 0.0.0.0 -n $(NAMESPACE_ARGOCD) 8080:443 >> /tmp/argocd-ui-pf.log 2>&1 &)
	@sleep 2
	@echo "✅ ArgoCD UI is now accessible at: https://localhost:8080"
	@echo "   Username: admin"
	@echo "   Password: admin123"
	@echo ""
	@echo "Note: Port-forward is running in background (logs: /tmp/argocd-ui-pf.log)"

# Show all pods
pods:
	@echo "===== All Pods ====="
	@kubectl get pods -A

# Show cluster status
status:
	@echo "===== Cluster Info ====="
	@k3d cluster list
	@echo ""
	@echo "===== ArgoCD Pods ====="
	@kubectl get pods -n $(NAMESPACE_ARGOCD) 2>/dev/null || echo "ArgoCD namespace not found"
	@echo ""
	@echo "===== Application Pods ====="
	@kubectl get pods -n $(NAMESPACE_DEV) 2>/dev/null || echo "Dev namespace not found"
	@echo ""
	@echo "===== ArgoCD Applications ====="
	@kubectl get applications -n $(NAMESPACE_ARGOCD) 2>/dev/null || echo "No applications found"

# Delete K3d cluster
clean:
	@echo "Deleting K3d cluster..."
	@k3d cluster delete $(CLUSTER_NAME) || true
	@echo "Cluster deleted."

fclean: clean
	@rm -f .prereq_done
	@echo "Cleaned all generated files."

# Restart the setup (clean + setup)
re: fclean
	@sleep 5
	@$(MAKE) setup

# Port-forward application with auto-reconnect
app:
	@echo "Starting auto-reconnecting port-forward..."
	@echo "This will automatically restart if the connection breaks"
	@echo "Press Ctrl+C to stop"
	@echo ""
	@chmod +x scripts/watch-app.sh
	@./scripts/watch-app.sh

all: install setup

# Help
help:
	@echo "Available targets:"
	@echo "  make all              - Install prerequisites and setup cluster (default)"
	@echo "  make install           - Install prerequisites (Docker, kubectl, k3d)"
	@echo "  make setup            - Setup K3d cluster and deploy ArgoCD (sync interval: 30s)"
	@echo "  make clean            - Delete the K3d cluster"
	@echo "  make fclean           - Delete cluster and remove .prereq_done"
	@echo "  make re               - Full clean and setup (fclean + setup)"
	@echo "  make status           - Show cluster and application status"
	@echo "  make ui               - Port-forward ArgoCD UI to localhost:8080"
	@echo "  make app              - Auto-reconnecting port-forward to localhost:8888"
	@echo "  make pods             - Show all pods in all namespaces"
	@echo "  make help             - Show this help message"

.PHONY: all install setup clean fclean re status ui pods app help
