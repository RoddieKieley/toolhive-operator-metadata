# Implementation Tasks: Add Scorecard Tests

**Feature**: Add Scorecard Tests (010-add-scorecard-tests)
**Branch**: `010-add-scorecard-tests`
**Date**: 2025-10-21

## Overview

This document provides the detailed task breakdown for implementing Operator SDK Scorecard validation testing. Tasks are organized by user story to enable independent implementation and testing of each increment.

**Total Tasks**: 18
**Parallel Opportunities**: 8 tasks can run in parallel
**MVP Scope**: Phase 3 (User Story 1) - Tasks T001-T008

## Task Organization

- **Phase 1**: Setup (project structure initialization)
- **Phase 2**: Foundational (scorecard configuration foundation)
- **Phase 3**: User Story 1 - Bundle Validation Before Deployment (P1 - MVP)
- **Phase 4**: User Story 2 - Automated Validation in Build Process (P2)
- **Phase 5**: User Story 3 - Comprehensive Test Coverage (P3)
- **Phase 6**: Polish & Documentation

---

## Phase 1: Setup

### T001 - Create scorecard directory structure

**Story**: Setup
**File**: `config/scorecard/` (new directory)
**Parallel**: No
**Depends on**: None

Create the scorecard configuration directory structure following the existing kustomize pattern.

**Implementation**:
```bash
mkdir -p config/scorecard
```

**Verification**: Directory exists at `config/scorecard/`

---

## Phase 2: Foundational

### T002 - Create scorecard configuration template

**Story**: Foundation
**File**: `config/scorecard/config.yaml`
**Parallel**: No
**Depends on**: T001

Create the scorecard configuration file with basic and OLM test suites.

**Implementation**: Create YAML configuration with:
- API version: scorecard.operatorframework.io/v1alpha3
- kind: Configuration
- 6 tests (1 basic + 5 OLM):
  - basic-check-spec-test
  - olm-bundle-validation-test
  - olm-crds-have-validation-test
  - olm-crds-have-resources-test
  - olm-spec-descriptors-test
  - olm-status-descriptors-test
- Test image: quay.io/operator-framework/scorecard-test:v1.41.0
- Parallel execution enabled (parallel: true)
- Empty storage configuration (mountPath: {})

**Verification**: YAML is valid; all 6 tests defined with correct entrypoints and labels

---

### T003 - Create scorecard kustomization file

**Story**: Foundation
**File**: `config/scorecard/kustomization.yaml`
**Parallel**: Yes (can run with T002)
**Depends on**: T001

Create kustomization.yaml for scorecard configuration.

**Implementation**: Create kustomization file that:
- References config.yaml
- Enables inclusion in bundle generation

**Verification**: Kustomization builds successfully

---

## Phase 3: User Story 1 - Bundle Validation Before Deployment (P1 - MVP)

**Goal**: Enable manual scorecard validation to catch bundle errors before deployment

**Independent Test**: Run `make scorecard-test` against generated bundle and verify all 6 tests pass

---

### T004 - [US1] Update bundle target to copy scorecard config

**Story**: US1
**File**: `Makefile` (bundle target)
**Parallel**: No
**Depends on**: T002, T003

Modify the bundle generation target to copy scorecard configuration from config/scorecard/ to bundle/tests/scorecard/.

**Implementation**: In bundle target, after bundle manifest generation:
1. Create bundle/tests/scorecard/ directory
2. Copy config/scorecard/config.yaml to bundle/tests/scorecard/config.yaml
3. Add informational echo message

**Verification**: After `make bundle`, file exists at `bundle/tests/scorecard/config.yaml`

---

### T005 - [US1] Update bundle annotations for scorecard

**Story**: US1
**File**: `Makefile` (bundle target, annotations section)
**Parallel**: No
**Depends on**: T004

Add scorecard annotations to bundle/metadata/annotations.yaml during bundle generation.

**Implementation**: Add annotations:
```yaml
operators.operatorframework.io.test.config.v1: tests/scorecard/
operators.operatorframework.io.test.mediatype.v1: scorecard+v1
```

**Verification**: Annotations exist in generated bundle/metadata/annotations.yaml

---

### T006 - [US1] Create check-scorecard-deps target

**Story**: US1
**File**: `Makefile` (new target)
**Parallel**: Yes (can run with T004, T005)
**Depends on**: None

Create Makefile target to verify scorecard prerequisites are installed.

**Implementation**: Add target that checks:
1. operator-sdk command exists (print version)
2. kubectl or oc command exists (print version)
3. Cluster is accessible (kubectl cluster-info)
4. Print ✓ or ✗ for each check
5. Exit 0 if all pass, 1 if any fail
6. Provide installation instructions in error messages

**Verification**: `make check-scorecard-deps` reports status correctly

---

### T007 - [US1] Create scorecard-test target

**Story**: US1
**File**: `Makefile` (new target)
**Parallel**: No
**Depends on**: T004, T005, T006

Create primary Makefile target to run scorecard validation.

**Implementation**: Add target that:
1. Checks for bundle/ directory (exit with error if missing)
2. Runs prerequisite check (make check-scorecard-deps)
3. Executes: `operator-sdk scorecard bundle/ -o text`
4. Captures exit code
5. Prints success/failure message
6. Returns scorecard exit code

**Target signature**:
```makefile
.PHONY: scorecard-test
scorecard-test: bundle ## Run scorecard tests against bundle
```

**Verification**: `make scorecard-test` executes and displays test results

---

### T008 - [US1] Test MVP workflow

**Story**: US1
**File**: Multiple (integration test)
**Parallel**: No
**Depends on**: T007

Verify the complete MVP workflow functions correctly.

**Implementation**: Execute and verify:
1. `make bundle` completes successfully
2. `bundle/tests/scorecard/config.yaml` exists
3. `make check-scorecard-deps` passes (or provides clear errors)
4. `make scorecard-test` executes (may fail if cluster unavailable)
5. Test results displayed in text format

**Verification**: Workflow completes; scorecard executes against bundle

**CHECKPOINT**: ✅ User Story 1 Complete - Manual scorecard validation works

---

## Phase 4: User Story 2 - Automated Validation in Build Process (P2)

**Goal**: Integrate scorecard into automated build workflow to prevent invalid bundles

**Independent Test**: Run `make validate-all` and verify scorecard executes as part of validation suite

---

### T009 - [US2] Integrate scorecard into validate-all target

**Story**: US2
**File**: `Makefile` (validate-all target)
**Parallel**: No
**Depends on**: T007

Add scorecard-test to the comprehensive validation workflow.

**Implementation**: Update validate-all target to:
1. Run existing validations (constitution-check, bundle-validate, catalog-validate)
2. Run scorecard-test after catalog-validate
3. Print section header for scorecard validation
4. Fail entire validation if scorecard fails

**Verification**: `make validate-all` includes scorecard; fails if scorecard fails

---

### T010 - [US2] Add scorecard to help target

**Story**: US2
**File**: `Makefile` (help documentation)
**Parallel**: Yes (can run with T009)
**Depends on**: T007

Add scorecard targets to Makefile help output.

**Implementation**: Add documentation comments:
```makefile
check-scorecard-deps: ## Check scorecard prerequisites
scorecard-test: ## Run scorecard tests against bundle
```

**Verification**: `make help` displays scorecard targets

---

### T011 - [US2] Update README with scorecard section

**Story**: US2
**File**: `README.md`
**Parallel**: Yes (can run with T009, T010)
**Depends on**: T007

Add scorecard documentation to main README.

**Implementation**: Add section after "Building OLM Catalog":
- What is scorecard
- Prerequisites (operator-sdk, cluster)
- Basic usage (`make scorecard-test`)
- Common issues and solutions
- Link to quickstart guide

**Verification**: README includes scorecard section with usage examples

---

### T012 - [US2] Test automated validation workflow

**Story**: US2
**File**: Multiple (integration test)
**Parallel**: No
**Depends on**: T009, T010, T011

Verify scorecard integrates correctly into automated workflows.

**Implementation**: Execute and verify:
1. `make validate-all` runs scorecard
2. Scorecard failure causes validate-all to fail
3. Help output shows scorecard targets
4. README documentation is clear and accurate

**Verification**: Scorecard fully integrated into validation workflow

**CHECKPOINT**: ✅ User Story 2 Complete - Automated scorecard validation works

---

## Phase 5: User Story 3 - Comprehensive Test Coverage (P3)

**Goal**: Enable comprehensive testing with selective suite execution and multiple output formats

**Independent Test**: Run `make scorecard-test-suite SUITE=basic` and verify only basic tests execute; run with `-o json` and verify JSON output

---

### T013 - [US3] Create scorecard-test-json target

**Story**: US3
**File**: `Makefile` (new target)
**Parallel**: Yes (can run with T014)
**Depends on**: T007

Create target for JSON output format (CI/CD integration).

**Implementation**: Add target:
```makefile
.PHONY: scorecard-test-json
scorecard-test-json: bundle ## Run scorecard tests with JSON output
	@operator-sdk scorecard bundle/ -o json
```

**Verification**: `make scorecard-test-json` outputs valid JSON

---

### T014 - [US3] Create scorecard-test-suite target with selector

**Story**: US3
**File**: `Makefile` (new target)
**Parallel**: Yes (can run with T013)
**Depends on**: T007

Create target for selective test suite execution.

**Implementation**: Add target with SUITE parameter:
```makefile
.PHONY: scorecard-test-suite
scorecard-test-suite: bundle ## Run specific test suite (SUITE=basic|olm)
	@if [ -z "$(SUITE)" ]; then \
		echo "❌ Error: SUITE parameter required"; \
		echo "Usage: make scorecard-test-suite SUITE=basic"; \
		exit 1; \
	fi
	@operator-sdk scorecard bundle/ --selector=suite=$(SUITE) -o text
```

**Verification**: `make scorecard-test-suite SUITE=basic` runs only basic tests

---

### T015 - [US3] Update help with new targets

**Story**: US3
**File**: `Makefile` (help documentation)
**Parallel**: Yes (can run with T013, T014)
**Depends on**: T010

Add documentation for new scorecard targets.

**Implementation**: Add comments:
```makefile
scorecard-test-json: ## Run scorecard tests with JSON output (for CI/CD)
scorecard-test-suite: ## Run specific test suite (SUITE=basic|olm)
```

**Verification**: `make help` shows all scorecard targets

---

### T016 - [US3] Test comprehensive coverage features

**Story**: US3
**File**: Multiple (integration test)
**Parallel**: No
**Depends on**: T013, T014, T015

Verify all test coverage features work correctly.

**Implementation**: Execute and verify:
1. `make scorecard-test-json` produces valid JSON output
2. `make scorecard-test-suite SUITE=basic` runs only 1 test
3. `make scorecard-test-suite SUITE=olm` runs only 5 tests
4. Error message shown when SUITE parameter missing
5. Help shows all targets

**Verification**: All scorecard features functional and documented

**CHECKPOINT**: ✅ User Story 3 Complete - Comprehensive test coverage available

---

## Phase 6: Polish & Documentation

### T017 - Update VALIDATION.md with scorecard status

**Story**: Polish
**File**: `VALIDATION.md`
**Parallel**: Yes (can run with T018)
**Depends on**: T009

Add scorecard validation status to validation documentation.

**Implementation**: Add section:
- Scorecard test status (number of tests, pass rate)
- Prerequisites for running scorecard
- Link to scorecard documentation
- Last validation date

**Verification**: VALIDATION.md includes scorecard section

---

### T018 - Add .gitignore entry for scorecard temp files

**Story**: Polish
**File**: `.gitignore`
**Parallel**: Yes (can run with T017)
**Depends on**: None

Ensure scorecard temporary files are not committed.

**Implementation**: Add entry:
```
# Scorecard temporary files
*_scorecard_*.json
scorecard-results.json
```

**Verification**: Git ignores scorecard result files

---

## Dependency Graph

```
Phase 1: Setup
  T001 (create directories)
    ↓
Phase 2: Foundation
  T002 (config.yaml) ← T001
  T003 (kustomization.yaml) ← T001 [P]
    ↓
Phase 3: User Story 1 (P1 - MVP)
  T004 (bundle target update) ← T002, T003
  T005 (bundle annotations) ← T004
  T006 (check-deps target) ← None [P]
  T007 (scorecard-test target) ← T004, T005, T006
  T008 (test MVP) ← T007
    ↓
Phase 4: User Story 2 (P2 - Automation)
  T009 (integrate validate-all) ← T007
  T010 (help target) ← T007 [P]
  T011 (README update) ← T007 [P]
  T012 (test automation) ← T009, T010, T011
    ↓
Phase 5: User Story 3 (P3 - Comprehensive)
  T013 (JSON output target) ← T007 [P]
  T014 (suite selector target) ← T007 [P]
  T015 (help update) ← T010, T013, T014 [P]
  T016 (test comprehensive) ← T013, T014, T015
    ↓
Phase 6: Polish
  T017 (VALIDATION.md) ← T009 [P]
  T018 (.gitignore) ← None [P]
```

## Parallel Execution Opportunities

### Within User Story 1 (MVP)
```bash
# Can run in parallel:
- T006 (check-deps target)
# While running sequentially:
- T004 (bundle update) → T005 (annotations) → T007 (scorecard-test)
```

### Within User Story 2 (Automation)
```bash
# Can run in parallel after T007:
- T010 (help)
- T011 (README)
# Then:
- T009 (validate-all integration) → T012 (test)
```

### Within User Story 3 (Comprehensive)
```bash
# Can run in parallel after T007:
- T013 (JSON target)
- T014 (suite selector)
# Then:
- T015 (help update) → T016 (test)
```

### Polish Phase
```bash
# Can run in parallel:
- T017 (VALIDATION.md)
- T018 (.gitignore)
```

**Total parallel opportunities**: 8 tasks

## Implementation Strategy

### MVP Delivery (User Story 1 Only)

**Tasks**: T001-T008 (8 tasks)
**Estimated effort**: 2-3 hours
**Deliverable**: Manual scorecard validation works

**Critical path**:
```
T001 → T002 → T004 → T005 → T007 → T008
     → T003 ↗       → T006 ↗
```

**Value delivered**:
- Scorecard configuration in place
- Manual validation via `make scorecard-test`
- Bundle generation includes scorecard config
- Prerequisite checking functional

### Incremental Delivery (Add User Story 2)

**Tasks**: T009-T012 (4 additional tasks)
**Estimated effort**: 1-2 hours
**Deliverable**: Automated scorecard in validation workflow

**Value delivered**:
- Scorecard integrated into `make validate-all`
- Prevents invalid bundles from passing validation
- Documentation updated
- Help system includes scorecard

### Complete Feature (Add User Story 3)

**Tasks**: T013-T016 (4 additional tasks)
**Estimated effort**: 1-2 hours
**Deliverable**: Comprehensive test coverage with flexibility

**Value delivered**:
- JSON output for CI/CD
- Selective suite execution for faster iteration
- Complete feature documentation
- All acceptance scenarios satisfied

### Polish

**Tasks**: T017-T018 (2 tasks)
**Estimated effort**: 30 minutes
**Deliverable**: Production-ready documentation and cleanup

## Testing Strategy

### Unit Testing (Per Task)
Each task includes verification criteria that can be tested independently.

### Integration Testing (Per User Story)
- T008: MVP workflow test
- T012: Automation workflow test
- T016: Comprehensive coverage test

### End-to-End Testing
After T016, run complete workflow:
```bash
make bundle
make check-scorecard-deps
make scorecard-test
make scorecard-test-json
make scorecard-test-suite SUITE=basic
make scorecard-test-suite SUITE=olm
make validate-all
```

## Success Criteria Mapping

| Success Criterion | Verified By | Phase |
|-------------------|-------------|-------|
| SC-001: Validation < 2 minutes | T008, T016 (measure execution time) | Phase 3, 5 |
| SC-002: 100% basic test pass | T008, T012, T016 (run tests, verify pass) | Phase 3, 4, 5 |
| SC-003: 100% OLM test pass | T008, T012, T016 (run tests, verify pass) | Phase 3, 4, 5 |
| SC-004: Build fails on test failure | T009, T012 (test validate-all failure) | Phase 4 |
| SC-005: Single command execution | T007, T008 (make scorecard-test works) | Phase 3 |
| SC-006: Actionable errors < 10 min | T006, T008 (verify error messages) | Phase 3 |

## File Modifications Summary

| File | Tasks | Type |
|------|-------|------|
| `config/scorecard/config.yaml` | T002 | Create |
| `config/scorecard/kustomization.yaml` | T003 | Create |
| `Makefile` | T004, T005, T006, T007, T009, T010, T013, T014, T015 | Update |
| `README.md` | T011 | Update |
| `VALIDATION.md` | T017 | Update |
| `.gitignore` | T018 | Update |

**New files**: 2
**Modified files**: 4
**Total changes**: 6 files

## Notes

- **No custom test images**: Using standard quay.io/operator-framework/scorecard-test:v1.41.0
- **No test writing**: This feature uses built-in scorecard tests only (basic + OLM suites)
- **Cluster dependency**: Scorecard requires Kubernetes cluster; tests may skip in environments without clusters
- **Constitutional compliance**: All tasks preserve manifest integrity, follow kustomize patterns, maintain CRD immutability
- **Incremental value**: Each user story delivers independent, testable functionality

## Next Steps After Task Completion

1. **Test against current bundle**: Verify all scorecard tests pass on toolhive-operator bundle
2. **Fix any test failures**: Address descriptor or validation issues identified by scorecard
3. **Document results**: Update VALIDATION.md with scorecard test results
4. **Create pull request**: Submit scorecard implementation for review
5. **CI/CD integration** (future): Add scorecard to GitHub Actions workflow
