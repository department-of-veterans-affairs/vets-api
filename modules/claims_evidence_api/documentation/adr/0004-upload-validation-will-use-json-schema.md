# 4. Upload validation will use JSON Schema

Date: 2025-07-01

## Status

Accepted

## Context

Validation of the upload metadata is required.

## Decision

Instead of creating a bespoke validation function, the module will make use of JSON Schema and the voxpupuli/json-schema gem.

## Consequences

The existing schema for Claims Evidence API can be reused (to an extent) and JSON Schema is a standard. There is a specific syntax required however and adding a custom validator is not simple.
