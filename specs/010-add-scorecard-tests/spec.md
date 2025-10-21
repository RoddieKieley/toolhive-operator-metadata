# Feature Specification: Add Scorecard Tests

**Feature Branch**: `010-add-scorecard-tests`
**Created**: 2025-10-21
**Status**: Draft
**Input**: User description: "Add scorecard tests. To ensure the validity of the metadata in this project prior to deployment we want to statically validate the bundle using Scorecard as per the Operator SDK Documentation on Testing Operators at https://sdk.operatorframework.io/docs/testing-operators. The Scorecard allows for the static validation of the operator bundle using the scorecard command which is a part of the operator-sdk. It requires a configuration file and test container images. This project must be updated to adhere to the requirements of the Scorecard tests such that the included metadata, manifests, and produced bundle and catalogs pass all scorecard tests."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Bundle Validation Before Deployment (Priority: P1)

As an operator maintainer, I need to validate my OLM bundle metadata is structurally correct and follows operator best practices before deploying to a cluster, so that I can catch configuration errors early in the development process and ensure successful operator installation.

**Why this priority**: This is the core value of scorecard - catching bundle validation errors before deployment prevents failed installations and reduces debugging time. This is the minimum viable functionality.

**Independent Test**: Can be fully tested by running scorecard against the generated bundle and verifying all basic and OLM suite tests pass. Delivers immediate value by validating bundle structure.

**Acceptance Scenarios**:

1. **Given** a freshly generated bundle exists, **When** scorecard validation is run, **Then** all basic tests pass (CRD spec validation, bundle structure)
2. **Given** bundle manifests contain errors, **When** scorecard validation is run, **Then** specific failing tests are reported with actionable error messages
3. **Given** scorecard tests pass, **When** building the bundle, **Then** maintainer has confidence the bundle structure is correct

---

### User Story 2 - Automated Validation in Build Process (Priority: P2)

As an operator maintainer, I need scorecard validation to run automatically as part of my build workflow, so that invalid bundles are never accidentally committed or published.

**Why this priority**: Automation prevents human error and ensures consistent validation. Builds on P1 by integrating validation into the workflow rather than requiring manual execution.

**Independent Test**: Can be tested by running `make` targets that invoke scorecard and fail the build when tests fail. Delivers value by preventing bad bundles from being created.

**Acceptance Scenarios**:

1. **Given** a Makefile target for validation exists, **When** I run the validation target, **Then** scorecard executes and returns success/failure status
2. **Given** scorecard tests fail, **When** building the bundle, **Then** the build process stops with an error message
3. **Given** scorecard tests pass, **When** building the catalog, **Then** the build continues successfully

---

### User Story 3 - Comprehensive Test Coverage (Priority: P3)

As an operator maintainer, I need to run the complete suite of scorecard tests including basic, OLM, and any custom tests, so that I can ensure comprehensive validation of all operator metadata aspects.

**Why this priority**: Complete test coverage provides maximum confidence but is not essential for initial MVP. Builds on P1 and P2 by expanding test scope.

**Independent Test**: Can be tested by running scorecard with all test suites enabled and verifying comprehensive test results. Delivers value through thorough validation.

**Acceptance Scenarios**:

1. **Given** scorecard configuration includes all test suites, **When** validation runs, **Then** basic, OLM, and custom tests all execute
2. **Given** specific test suites need selective execution, **When** using test selectors, **Then** only desired test suites run
3. **Given** test results are generated, **When** reviewing output, **Then** results are available in multiple formats (JSON, text, XML)

---

### Edge Cases

- What happens when scorecard configuration file is missing or malformed?
- How does the system handle scorecard execution when operator-sdk is not installed?
- What occurs when test container images cannot be pulled from registry?
- How are scorecard test failures distinguished from command execution failures?
- What happens when running scorecard without a Kubernetes cluster available?
- How does scorecard validation handle bundles with custom resources not following standard patterns?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a scorecard configuration file at `bundle/tests/scorecard/config.yaml` that defines basic and OLM test suites
- **FR-002**: System MUST include a build target that executes scorecard validation against the generated bundle
- **FR-003**: Scorecard validation MUST run against the bundle directory structure (not requiring containerization for basic validation)
- **FR-004**: System MUST report scorecard test results with clear pass/fail status for each test
- **FR-005**: System MUST fail the build process when scorecard tests fail
- **FR-006**: Scorecard tests MUST validate Custom Resource Definitions include spec blocks
- **FR-007**: Scorecard tests MUST validate bundle structure and metadata completeness
- **FR-008**: Scorecard tests MUST validate ClusterServiceVersion (CSV) resources and descriptors
- **FR-009**: System MUST support selective execution of test suites (basic, olm) via test selectors
- **FR-010**: System MUST provide documentation on running scorecard tests manually and as part of the build
- **FR-011**: Scorecard configuration MUST specify test images, entrypoints, and labels for each test
- **FR-012**: System MUST integrate scorecard validation into the existing `validate-all` target
- **FR-013**: System MUST provide clear error messages when scorecard prerequisites (operator-sdk, cluster access) are missing
- **FR-014**: Scorecard validation MUST check bundle annotations for correct values
- **FR-015**: System MUST support running scorecard tests without requiring bundle containerization for rapid iteration

### Non-Functional Requirements

- **NFR-001**: Scorecard validation MUST complete within 2 minutes for typical bundles
- **NFR-002**: Error messages MUST include specific test names and failure reasons to enable quick debugging
- **NFR-003**: Configuration file MUST be maintainable without requiring deep Kubernetes expertise
- **NFR-004**: Scorecard execution MUST not modify bundle files or leave temporary artifacts

### Key Entities

- **Scorecard Configuration**: Defines test suites, stages, test images, and execution parameters; stored in `bundle/tests/scorecard/config.yaml`
- **Test Suite**: Collection of related tests (basic, olm); each suite validates specific aspects of the bundle
- **Test Result**: Outcome of individual test execution including pass/fail status, logs, and error details
- **Bundle Directory**: Target of scorecard validation containing manifests, CRDs, and metadata

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Bundle validation completes in under 2 minutes for the toolhive-operator bundle
- **SC-002**: All generated bundles pass 100% of basic scorecard tests (CRD spec validation, bundle structure)
- **SC-003**: All generated bundles pass 100% of OLM scorecard tests (bundle validation, CSV descriptors, API validation)
- **SC-004**: Build process fails immediately when scorecard tests fail, preventing invalid bundles from being published
- **SC-005**: Maintainers can run scorecard validation with a single command (`make scorecard-test` or similar)
- **SC-006**: Scorecard test failures provide actionable error messages that allow fixing issues within 10 minutes

## Assumptions *(optional)*

- operator-sdk is available in the development environment (added to prerequisites)
- Access to a Kubernetes cluster is available for scorecard execution (can be kind, minikube, or remote cluster)
- Test container images are publicly available from quay.io/operator-framework
- The bundle structure follows Operator Framework standards (already established by previous features)
- Scorecard version is compatible with operator-sdk version used in the project
- Network access is available to pull test container images

## Dependencies *(optional)*

- **External**: operator-sdk CLI tool must be installed
- **External**: Kubernetes cluster access (any cluster - kind, minikube, OpenShift, etc.)
- **External**: Test container images from quay.io/operator-framework
- **Internal**: Bundle generation must complete successfully before scorecard can run
- **Internal**: Existing validation targets (bundle-validate, catalog-validate) should remain independent

## Out of Scope *(optional)*

- Writing custom scorecard tests (only using built-in basic and OLM suites)
- Integration with CI/CD platforms (GitHub Actions, GitLab CI, etc.) - only local execution and Makefile integration
- Performance testing of the operator runtime (scorecard is static validation only)
- End-to-end operator functionality testing (scorecard validates metadata, not runtime behavior)
- Automated remediation of scorecard test failures (only detection and reporting)
- Scorecard execution against containerized bundles (focus on bundle directory validation for rapid iteration)

## Risks *(optional)*

- **Risk**: Scorecard requires Kubernetes cluster access which may not be available in all environments
  - **Mitigation**: Document alternative validation methods; provide instructions for setting up local kind/minikube cluster

- **Risk**: Test container image pulls may fail due to network issues or registry outages
  - **Mitigation**: Document troubleshooting steps; consider caching test images locally

- **Risk**: Scorecard configuration may become outdated as Operator Framework evolves
  - **Mitigation**: Pin to specific test image versions; document version compatibility; include config in version control

- **Risk**: Scorecard tests may fail on valid bundles due to strict validation rules
  - **Mitigation**: Understand each test requirement; document any expected test skips with justification

## Related Work *(optional)*

- **Feature 008**: Security context fixes for OpenShift compatibility - scorecard validates these configurations
- **Feature 009**: Icon customization - scorecard validates icon metadata in CSV
- **Existing validation**: bundle-validate, catalog-validate, constitution-check - scorecard complements these
- **Operator SDK Documentation**: https://sdk.operatorframework.io/docs/testing-operators/scorecard/
- **OLM Bundle Validation**: Scorecard enforces OLM bundle best practices established in operator-framework/api
