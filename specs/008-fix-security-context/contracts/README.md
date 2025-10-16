# Contracts: Security Context Fix

This directory contains contract definitions for the security context fix feature. These contracts define the expected structure and behavior of the security context configuration for OpenShift compliance.

## Contract Files

### [kustomize-patches.yaml](kustomize-patches.yaml)

Defines the kustomize JSON patch operations required to modify the operator deployment manifests for OpenShift compatibility. Includes:

- Required patch operations (add seccompProfile, remove runAsUser)
- Conditional patches for upstream changes
- Validation rules for patch application
- Integration requirements for kustomization.yaml
- Testing contracts for build and deployment verification

**Purpose**: Ensures kustomize patches are correctly structured and applied to produce compliant manifests.

### [security-context-schema.yaml](security-context-schema.yaml)

Defines the schema for pod and container security contexts that comply with OpenShift restricted-v2 SCC. Includes:

- Pod security context schema with required fields
- Container security context schema with required fields
- Complete example of compliant configuration
- OpenShift restricted-v2 SCC compatibility matrix
- Validation rules with severity levels
- Reference documentation links

**Purpose**: Provides a formal specification of the security context structure that must be achieved.

## Usage

These contracts serve as:

1. **Implementation Guides**: Define what needs to be implemented
2. **Validation Criteria**: Specify how to verify correct implementation
3. **Documentation**: Explain why each field is required
4. **Testing Specifications**: Provide concrete test cases

## Validation Commands

### Verify Kustomize Build Output

```bash
# Build and check for runAsUser absence
kustomize build config/base | yq '.spec.template.spec.containers[0].securityContext.runAsUser'
# Expected: null

# Check seccompProfile
kustomize build config/base | yq '.spec.template.spec.securityContext.seccompProfile.type'
# Expected: "RuntimeDefault"

# Check runAsNonRoot at pod level
kustomize build config/base | yq '.spec.template.spec.securityContext.runAsNonRoot'
# Expected: true

# Check runAsNonRoot at container level
kustomize build config/base | yq '.spec.template.spec.containers[0].securityContext.runAsNonRoot'
# Expected: true

# Check allowPrivilegeEscalation
kustomize build config/base | yq '.spec.template.spec.containers[0].securityContext.allowPrivilegeEscalation'
# Expected: false

# Check readOnlyRootFilesystem
kustomize build config/base | yq '.spec.template.spec.containers[0].securityContext.readOnlyRootFilesystem'
# Expected: true

# Check capabilities
kustomize build config/base | yq '.spec.template.spec.containers[0].securityContext.capabilities.drop'
# Expected: ["ALL"]
```

### Verify OpenShift Deployment

```bash
# Deploy to OpenShift
oc apply -k config/base

# Wait for pod to be ready
oc wait --for=condition=Ready pod -l control-plane=controller-manager --timeout=120s

# Check pod events for security violations
oc describe pod -l control-plane=controller-manager | grep -i "security\|violation\|forbidden"
# Expected: No security violation messages

# Verify assigned UID is not 1000
oc get pod -l control-plane=controller-manager -o jsonpath='{.items[0].status.containerStatuses[0].user.uid}'
# Expected: A UID other than 1000 (dynamically assigned by OpenShift)
```

## Contract Compliance Checklist

- [ ] Kustomize patches defined in [kustomize-patches.yaml](kustomize-patches.yaml)
- [ ] Patches correctly target apps/v1/Deployment/controller-manager
- [ ] runAsUser field is removed (not replaced with different value)
- [ ] seccompProfile.type set to RuntimeDefault
- [ ] All required security context fields present in output
- [ ] No prohibited fields (runAsUser) in output
- [ ] Kustomize build succeeds without errors
- [ ] Output complies with schema in [security-context-schema.yaml](security-context-schema.yaml)
- [ ] All validation rules pass
- [ ] Pod starts successfully in OpenShift
- [ ] No security context violations in pod events

## Notes

- These contracts are declarative specifications, not executable code
- YAML format chosen for consistency with Kubernetes manifests
- Contract validation is performed during implementation and testing phases
- Contracts should be updated if requirements change
