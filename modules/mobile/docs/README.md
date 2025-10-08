# Mobile API Documentation

This directory contains the OpenAPI specification and documentation for the VA Mobile API.

## Files

- `openapi.yaml` - Source of truth for API documentation (edit this file)
- `openapi.json` - Generated JSON version of the spec
- `index.html` - Generated static HTML documentation
- `generate_static_docs.sh` - Script to manually generate static docs
- `validate_route_coverage.rb` - Script to validate all routes are documented

## Automated Documentation Generation

When you modify `openapi.yaml` or `routes.rb` in a pull request, a GitHub Action automatically:

1. **Validates route coverage** - Ensures all routes in `config/routes.rb` are documented in `openapi.yaml`
2. **Generates static docs** - Creates `index.html` and `openapi.json` from `openapi.yaml`
3. **Commits changes** - Automatically commits the generated files to your PR branch

This means you only need to edit `openapi.yaml` - the other files are generated for you!

## Manual Generation

If you need to generate the docs locally:

```bash
cd modules/mobile/docs
./generate_static_docs.sh
```

## Validating Route Coverage

To check if all routes are documented:

```bash
cd modules/mobile/docs
ruby validate_route_coverage.rb ../config/routes.rb openapi.yaml
```

This will exit with an error code and list any undocumented routes.

## Adding New Routes

When you add a new route to `config/routes.rb`:

1. Add the corresponding path and methods to `openapi.yaml`
2. Create a PR - the GitHub Action will validate and generate docs automatically
3. If routes are missing from the OpenAPI spec, the action will fail and list them

## Viewing Documentation

The generated `index.html` can be opened in any browser to view the interactive API documentation.
