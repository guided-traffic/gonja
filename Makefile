# Go commands
GOCMD = go
GOTEST = $(GOCMD) test
GOFMT = gofmt

# Coverage directory
COVERAGE_DIR = coverage

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands like 'source' to be used
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

.PHONY: all
all: fmt vet test

##@ General

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: fmt
fmt: ## Run go fmt against code.
	@echo "Formatting code..."
	$(GOFMT) -s -w .

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

.PHONY: lint
lint: ## Run linting.
	@echo "Running static analysis..."
	go vet ./...
	$(GOFMT) -l .
	@which golangci-lint > /dev/null || (echo "Installing golangci-lint..." && go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION))
	golangci-lint run --timeout=5m

.PHONY: lint-fix
lint-fix: golangci-lint ## Run golangci-lint linter and perform fixes.
	$(GOLANGCI_LINT) run --fix

.PHONY: cyclo
cyclo: ## Run cyclomatic complexity analysis.
	@echo "Running cyclomatic complexity analysis (threshold: $(CYCLO_THRESHOLD))..."
	@which gocyclo > /dev/null || (echo "Installing gocyclo..." && go install github.com/fzipp/gocyclo/cmd/gocyclo@$(GOCYCLO_VERSION))
	@gocyclo -over $(CYCLO_THRESHOLD) -ignore "_test.go" . && echo "✅ All functions are below complexity threshold $(CYCLO_THRESHOLD)" || (echo "❌ Functions above complexity threshold $(CYCLO_THRESHOLD) found!" && gocyclo -over $(CYCLO_THRESHOLD) -ignore "_test.go" . && exit 1)

.PHONY: cyclo-report
cyclo-report: ## Show full cyclomatic complexity report (including tests).
	@echo "Cyclomatic complexity report (sorted by complexity):"
	@which gocyclo > /dev/null || (echo "Installing gocyclo..." && go install github.com/fzipp/gocyclo/cmd/gocyclo@$(GOCYCLO_VERSION))
	@gocyclo -top 20 .

##@ Testing

.PHONY: test
test: fmt vet ## Run unit tests.
	$(GOTEST) ./...

.PHONY: test-unit
test-unit: ## Run unit tests only (no golden-file tests).
	@echo "Running unit tests..."
	$(GOTEST) -v -short ./...

.PHONY: test-unit-coverage
test-unit-coverage: ## Run unit tests with coverage.
	@echo "Running unit tests with coverage..."
	@mkdir -p $(COVERAGE_DIR)
	$(GOTEST) -v -short -coverpkg=./... -coverprofile=$(COVERAGE_DIR)/unit.out -covermode=atomic ./...

.PHONY: test-integration
test-integration: ## Run integration (golden-file) tests.
	@echo "Running integration tests..."
	$(GOTEST) -v -tags=integration -count=1 ./...

.PHONY: test-integration-coverage
test-integration-coverage: ## Run integration tests with coverage.
	@echo "Running integration tests with coverage..."
	@mkdir -p $(COVERAGE_DIR)
	$(GOTEST) -v -tags=integration -count=1 -coverpkg=./... -coverprofile=$(COVERAGE_DIR)/integration.out -covermode=atomic ./...

.PHONY: test-all
test-all: test-unit test-integration ## Run all tests (unit + integration).

.PHONY: test-coverage
test-coverage: ## Run all tests and show coverage report.
	@mkdir -p $(COVERAGE_DIR)
	$(GOTEST) -tags=integration -coverpkg=./... -coverprofile=$(COVERAGE_DIR)/cover.out ./...
	$(GOCMD) tool cover -html=$(COVERAGE_DIR)/cover.out -o $(COVERAGE_DIR)/coverage.html
	@echo "Coverage report generated at $(COVERAGE_DIR)/coverage.html"

##@ Coverage

.PHONY: coverage
coverage: ## Generate test coverage report.
	@echo "Generating coverage report..."
	@mkdir -p $(COVERAGE_DIR)
	$(GOTEST) -tags=integration -coverpkg=./... -coverprofile=$(COVERAGE_DIR)/coverage.out ./...
	$(GOCMD) tool cover -html=$(COVERAGE_DIR)/coverage.out -o $(COVERAGE_DIR)/coverage.html
	$(GOCMD) tool cover -func=$(COVERAGE_DIR)/coverage.out > $(COVERAGE_DIR)/coverage.txt
	@echo "Coverage report generated at $(COVERAGE_DIR)/coverage.html"
	@echo "Coverage summary:"
	@grep "total:" $(COVERAGE_DIR)/coverage.txt

.PHONY: coverage-ci
coverage-ci: ## Generate CI coverage report.
	@echo "Generating CI coverage report..."
	@mkdir -p $(COVERAGE_DIR)
	$(GOTEST) -tags=integration -coverpkg=./... -coverprofile=$(COVERAGE_DIR)/coverage.out ./...
	$(GOCMD) tool cover -func=$(COVERAGE_DIR)/coverage.out > $(COVERAGE_DIR)/coverage.txt
	@grep "total:" $(COVERAGE_DIR)/coverage.txt

.PHONY: coverage-merge
coverage-merge: ## Merge unit and integration coverage profiles.
	@echo "Merging coverage profiles..."
	@mkdir -p $(COVERAGE_DIR)
	@# Install gocovmerge if not present
	@which gocovmerge > /dev/null || (echo "Installing gocovmerge..." && go install github.com/wadey/gocovmerge@latest)
	@# Merge coverage files
	gocovmerge $(COVERAGE_DIR)/unit.out $(COVERAGE_DIR)/integration.out > $(COVERAGE_DIR)/combined.out
	$(GOCMD) tool cover -func=$(COVERAGE_DIR)/combined.out > $(COVERAGE_DIR)/combined.txt
	@echo "Combined coverage:"
	@grep "total:" $(COVERAGE_DIR)/combined.txt

.PHONY: coverage-json
coverage-json: ## Generate coverage badge JSON for shields.io.
	@echo "Generating coverage badge JSON..."
	@mkdir -p .github/badges
	@COVERAGE=$$(grep "total:" $(COVERAGE_DIR)/combined.txt | awk '{print $$3}' | sed 's/%//'); \
	COLOR="red"; \
	if [ $$(echo "$$COVERAGE >= 80" | bc -l) -eq 1 ]; then COLOR="brightgreen"; \
	elif [ $$(echo "$$COVERAGE >= 60" | bc -l) -eq 1 ]; then COLOR="green"; \
	elif [ $$(echo "$$COVERAGE >= 40" | bc -l) -eq 1 ]; then COLOR="yellow"; \
	elif [ $$(echo "$$COVERAGE >= 20" | bc -l) -eq 1 ]; then COLOR="orange"; \
	fi; \
	echo "{\"schemaVersion\":1,\"label\":\"coverage\",\"message\":\"$$COVERAGE%\",\"color\":\"$$COLOR\"}" > .github/badges/coverage.json
	@echo "Badge JSON created at .github/badges/coverage.json"
	@cat .github/badges/coverage.json

##@ Security

.PHONY: gosec
gosec: ## Run gosec security scan.
	@echo "Running gosec security scan..."
	@which gosec > /dev/null || (echo "Installing gosec..." && go install github.com/securego/gosec/v2/cmd/gosec@$(GOSEC_VERSION))
	GOFLAGS="-buildvcs=false" gosec ./...

.PHONY: vuln
vuln: ## Check for vulnerabilities.
	@echo "Checking for vulnerabilities..."
	@which govulncheck > /dev/null || (echo "Installing govulncheck..." && go install golang.org/x/vuln/cmd/govulncheck@latest)
	GOFLAGS="-buildvcs=false" govulncheck ./...

##@ Dependencies

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

## Tool Binaries
GOLANGCI_LINT ?= $(LOCALBIN)/golangci-lint

## Tool Versions
GOLANGCI_LINT_VERSION ?= v1.55.2
GOCYCLO_VERSION ?= v0.6.0
GOSEC_VERSION ?= v2.22.0

# Cyclomatic complexity threshold (recommended: 10-15)
CYCLO_THRESHOLD ?= 15

.PHONY: golangci-lint
golangci-lint: $(GOLANGCI_LINT) ## Download golangci-lint locally if necessary.
$(GOLANGCI_LINT): $(LOCALBIN)
	$(call go-install-tool,$(GOLANGCI_LINT),github.com/golangci/golangci-lint/cmd/golangci-lint,$(GOLANGCI_LINT_VERSION))

# go-install-tool will 'go install' any package with custom target and target path
define go-install-tool
@[ -f $(1) ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
GOBIN=$(LOCALBIN) go install $${package} ;\
}
endef

.PHONY: clean
clean: ## Remove build artifacts and coverage reports.
	rm -rf $(COVERAGE_DIR) $(LOCALBIN)
