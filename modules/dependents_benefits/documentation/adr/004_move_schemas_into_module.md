# 4. Move JSON Schemas into Module

Date: 2025-02-05

## Status

Accepted

## Context

Historically, form JSON schemas for VA.gov were maintained in the separate [vets-json-schema](https://github.com/department-of-veterans-affairs/vets-json-schema) repository. This approach made sense when both the frontend (vets-website) and backend (vets-api) needed to share schema definitions for form validation.

However, the frontend has since migrated away from using vets-json-schema for validation. The backend (vets-api) remains the sole consumer of these schemas, using them to validate form submissions before processing.

For the dependents benefits module (forms 21-674, 21-686C, 686C-674), this created several issues:

1. **Unnecessary dependency**: The dependents benefits frontend does not use vets-json-schema, making the backend the sole consumer of these specific schemas
2. **Deployment coordination**: Schema changes required coordinating releases across two repositories
3. **Version management**: The dependents team had to manage version pinning in vets-api to reference specific schema versions
4. **Development overhead**: Simple schema updates required PRs in two repositories and waiting for CI/CD pipelines in both
5. **Lack of cohesion**: Schema definitions were separated from the code that validates and processes the forms

## Decision

We will move the JSON schemas for dependents benefits forms (21-674.json, 21-686C.json, 686C-674.json) directly into the `dependents_benefits` module at `modules/dependents_benefits/schema/`.

The `FORM_SCHEMA_BASE` constant now points to the local schema directory:
```ruby
FORM_SCHEMA_BASE = "#{MODULE_PATH}/schema".freeze
```

This allows the module to load schemas directly without external dependencies:
```ruby
def form_schema(form_id)
  path = "#{DependentsBenefits::FORM_SCHEMA_BASE}/#{form_id.sub('-V2', '')}.json"
  MultiJson.load(File.read(path))
end
```

## Alternatives Considered

### Continue using vets-json-schema
**Pros:**
- Maintains historical approach
- Centralized schema repository

**Cons:**
- Unnecessary complexity when the dependents benefits frontend doesn't consume these schemas
- Deployment coordination overhead
- The dependents benefits team doesn't benefit from centralization since their frontend doesn't use these schemas

## Notes

This decision is specific to the dependents_benefits module. Other modules may choose to:
- Continue using vets-json-schema if it provides value
- Migrate their schemas locally if they are the sole consumer
- Share schemas across modules if needed by creating shared schema locations in vets-api
