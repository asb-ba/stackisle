# mk/ — Makefile extensions

Every `mk/*.mk` file is auto-included by the root `Makefile`.
Add a new stack (Magento, Kubernetes, Terraform, ...) without touching the core:

```make
# mk/magento.mk
##@ Magento
.PHONY: magento-start
magento-start: ## Start Magento containers
	@bash scripts/magento/start.sh
```

Conventions:
- Prefix targets with the stack name (`magento-*`, `k8s-*`) to avoid clashes.
- Put `## description` after the target so it shows in `make help`; `##@ Title` starts a section.
- Stack scripts live in `scripts/<stack>/` and should `source scripts/lib/common.sh`.
- Hook into the default flow with extra prerequisites, e.g. `all: magento-start`.
