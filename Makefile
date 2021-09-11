SHELL = /bin/bash
.DEFAULT_GOAL := help

context ?= $(shell kubectl config current-context)
tag ?= $(shell echo `whoami`"-dev")
registry := registry.gitlab.com/marekli/common
app := dropbox-kubernetes

# Text colors
TEXT_BOLD := $(shell tput -Txterm bold)
TEXT_RED := $(shell tput -Txterm setaf 1)
TEXT_GREEN := $(shell tput -Txterm setaf 2)
TEXT_YELLOW := $(shell tput -Txterm setaf 3)
TEXT_PURPLE := $(shell tput -Txterm setaf 5)
TEXT_WHITE := $(shell tput -Txterm setaf 7)
TEXT_RESET := $(shell tput -Txterm sgr0)

LG_ARROW := $(TEXT_BOLD)$(TEXT_GREEN)==>$(TEXT_RESET)
ARROW := $(TEXT_PURPLE)->$(TEXT_RESET)

# And add help text after each target name starting with ##
# A category can be added with @category
HELP_FUN = \
	%help; \
	while(<>) { push @{$$help{$$2 // 'options'}}, [$$1, $$3] if /^([a-zA-Z\-]+)\s*:.*\#\#(?:@([a-zA-Z\-]+))?\s(.*)$$/ }; \
	print "Usage: make [target] (option=value)\n\n"; \
	for (sort keys %help) { \
	print "${TEXT_WHITE}$$_:${TEXT_RESET}\n"; \
	for (@{$$help{$$_}}) { \
	$$sep = " " x (30 - length $$_->[0]); \
	print "  ${TEXT_YELLOW}$$_->[0]${TEXT_RESET}$$sep${TEXT_GREEN}$$_->[1]${TEXT_RESET}\n"; \
	}; \
	print "\n"; }

help: ##@Other Show this help.
	@perl -e '$(HELP_FUN)' $(MAKEFILE_LIST)

###########
## Build ##
###########

.PHONY: build
build: ##@Build Build the custom dropbox docker image Options: tag
	@echo "$(LG_ARROW) Building image $(registry)/$(app):$(tag)"
	@docker \
		build \
		-t $(registry)/$(app):$(tag) \
		-f Dockerfile \
		.

PHONY: build-clean
build-clean: ##@Build Build the custom dropbox docker image without cache. Options: tag
	@echo "$(LG_ARROW) Building image without cache $(registry)/$(app):$(TEXT_RED)$(tag)$(TEXT_RESET)"
	@docker \
		build \
		--pull \
		--no-cache \
		-t $(registry)/$(app):$(tag) \
		-f Dockerfile \
		.

.PHONY: push
push: build ##@Build Build and push the dropbox docker image. Options: tag
	@echo "$(LG_ARROW) Pushing image $(registry)/$(app):$(tag)"
	@docker \
		push \
		$(registry)/$(app):$(tag)

###########
## Build ##
###########

.PHONY: lint
lint: ##@Dev Lint the dockerfile
	@echo "$(LG_ARROW) Linting Dockerfile using hadolint"
	@echo "    For rule descriptions see: $(TEXT_YELLOW)https://github.com/hadolint/hadolint#rules$(TEXT_RESET)"
	@# Run with --no-fail since this dockerfile is just copied from upstream
	@docker \
		run \
		--rm \
		-i \
		hadolint/hadolint \
		hadolint \
		--no-fail \
		- \
		< Dockerfile

################
## Kubernetes ##
################

.PHONY: generate-pull-secret
generate-pull-secret: ##@Kubernetes Create or update the sealed pull secret. Options: context
	@echo "$(LG_ARROW) Generating image pull secret"
	@echo "The docker images are stored in GitLab. You can generate"
	@echo "a Deploy Token with the read_registry permission to use for the"
	@echo "image pull secret at:"
	@echo "$(ARROW) https://gitlab.com/marekli/common/-/settings/repository"
	@echo
	@read -p "Deploy Token Username: " USERNAME; \
	read -sp "Deploy Token Password: " PASSWORD; \
	echo; \
	read -p "Registry URL [registry.gitlab.com]: " REGISTRY; \
	export REGISTRY=$${REGISTRY:-registry.gitlab.com}; \
	echo; \
	kubectl \
		--context $(context) \
		--namespace dropbox \
		create \
		secret \
		docker-registry \
		pull-secret \
		--docker-server=$$REGISTRY \
		--docker-username=$$USERNAME \
		--docker-password=$$PASSWORD \
		--save-config \
		--dry-run=client \
		-o yaml \
	| kubeseal \
		--controller-name sealed-secrets \
		--controller-namespace sealed-secrets \
		-o yaml \
		> kubernetes/sealed-pull-secret.yaml; \
	echo "$(ARROW) kubernetes/sealed-pull-secret.yaml";
