---
applyTo: "spec/support/vcr_cassettes/**/*"
---

# Copilot Instructions for VCR Cassettes

**Path-Specific Instructions for VCR Cassettes**

These instructions automatically apply when working with VCR cassette files (YAML).

## 🛠️ Tool Usage

### `vcr_inspect_cassette`
**ALWAYS** use the `vcr_inspect_cassette` tool when you need to:
- Read the content of a VCR cassette.
- Analyze the interactions within a cassette.
- Debug or inspect recorded HTTP requests/responses.
- Count records or verify data within a cassette.

**Filtering with JMESPath:**
The tool supports an optional `query` parameter to filter the output using JMESPath. This is highly recommended for large cassettes to avoid token limits and get precise data.

**Examples:**
- Inspect full cassette: `vcr_inspect_cassette(cassette_path: "my_cassette")`
- Count active prescriptions: `vcr_inspect_cassette(cassette_path: "my_cassette", query: "interactions[].response.body.json.entry[?resource.resourceType=='MedicationRequest' && resource.status=='active'] | length(@)")`
- Get all IDs: `vcr_inspect_cassette(cassette_path: "my_cassette", query: "interactions[].response.body.json.entry[].resource.id")`

**DO NOT** use `read_file` or `grep` on VCR cassette files unless specifically asked to inspect the raw YAML structure (e.g., checking for merge conflicts or YAML syntax errors). The `vcr_inspect_cassette` tool provides a decoded, human-readable format that handles:
- Gzipped bodies
- JSON formatting
- Interaction separation

### Examples

**❌ Bad:**
"I'll read the cassette file to see the response."
`read_file(filePath: "spec/fixtures/vcr_cassettes/my_cassette.yml")`

**✅ Good:**
"I'll inspect the cassette to see the recorded response."
`vcr_inspect_cassette(cassette_path: "my_cassette")`
