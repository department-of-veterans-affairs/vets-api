# Mobile API Documentation

This directory contains the OpenAPI specification and documentation for the VA Mobile API.

## Files

- `openapi.yaml` - Source of truth for API documentation (edit this file)
- `openapi.json` - Generated JSON version of the spec (auto-generated, do not edit)
- `index.html` - Generated static HTML documentation (auto-generated, do not edit)
- `schemas/` - Reusable schema definitions referenced in openapi.yaml
- `examples/` - Example request/response payloads
- `params/` - Reusable parameter definitions
- `generate_static_docs.sh` - Script to manually generate static docs
- `validate_route_coverage.rb` - Script to validate all routes are documented

## Automated Documentation Generation

When you modify `openapi.yaml`, `routes.rb`, schemas, examples, or params in a pull request, a GitHub Action automatically:

1. **Validates route coverage** - Ensures all routes in `config/routes.rb` are documented in `openapi.yaml`
   - Uses flexible parameter matching (e.g., `{id}` in routes matches `{appointmentId}` in OpenAPI)
   - Fails the build if undocumented routes are found
2. **Generates static docs** - Creates `index.html` and `openapi.json` from `openapi.yaml`
3. **Commits changes** - Automatically commits the generated files to your PR branch

This means you only need to edit `openapi.yaml` and related schema files - the static files are generated for you!

## Manual Generation

If you need to generate the docs locally:

```bash
cd modules/mobile/docs
./generate_static_docs.sh
```

Note: You may need to install `redocly` in order to use the `./generate_static_docs.sh` script 

```npm install -g @redocly/cli```


## Validating Route Coverage

To check if all routes are documented:

```bash
cd modules/mobile/docs
ruby validate_route_coverage.rb ../config/routes.rb openapi.yaml
```

This will exit with an error code and list any undocumented routes.

### Parameter Matching

The validation script uses flexible parameter matching, which means:
- Routes like `/appointments/cancel/:id` in `routes.rb` will match `/appointments/cancel/{cancelId}` in `openapi.yaml`
- Parameter names don't need to be identical - any path parameter matches as long as it's in the same position
- This allows for more descriptive parameter names in the OpenAPI spec (e.g., `{appointmentId}`, `{facilityId}`) while keeping simpler names in routes

## Adding New Routes

When you add a new route to `config/routes.rb`:

1. Add the corresponding path and methods to `openapi.yaml`
2. Create a PR - the GitHub Action will validate and generate docs automatically
3. If routes are missing from the OpenAPI spec, the action will fail and list them

## Viewing Documentation

The generated `index.html` located in `modules/mobile/docs/index.html` can be used to view the documentation.

Your can either right-click and open the html file in the browser if there is an option to, or copy the absolute path of the file and paste it into the browser to view the interactive API documentation.
