# 9. Add versioning to vets-json-schema

Date: 2024-10-18

## Status

Proposed

## Context

When several teams are concurrently working to update vets-json-schema, a queuing effect can occur where teams are unable to proceed until everyone before them has completed their changes.
Each time a team does an update, the next team needs to come in and bump the package.json version.  This means that concurrent changes by multiple teams are slow and difficult and thus slow down development.
This can be especially a problem when breaking changes are made.  For example, a field in a schema is changed to use different enum values, which breaks tests in vets-api/vets-website that look for the previous values.

## Decision

The proposal is that when the build is run from package.json, (which kicks offsrc/generate-schemas.js ), we would version the schemas based upon the version in package.json
This would look something like:
```
dist/version/24.3.3/
                                21p-527-schema.json
                                10-10CG-schema.json
                                etc
dist/version/24.3.4
                                21p-527-schema.json
                                10-10CG-schema.json
                                etc
```

This would not be a breaking change, but something we'd like teams to adopt over time.
The existing folder structure would remain:
```
dist/
                                21p-527-schema.json
                                10-10CG-schema.json
```
For teams to take advantage of this change, they would change their import of vets-json-schema within vets-api to use a particular version needed.
Once teams start to opt-in to this, it would mean that when they change the schema they reference in vets-api, they can use that particular version in their code.
This could be done within a global config file:
```
schema = VetsJsonSchema::SCHEMAS[THE_VERSION_YOU_WANT][self.class::FORM]
```

## Consequences

Propogating this change across all VFS teams would result in a more efficient workflow and would provide greater flexibility for using the vets-json-schema.
