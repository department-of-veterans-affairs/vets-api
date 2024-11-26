# Benefits Claims API

## Connecting to upstream services locally
Note: Ensure correct localhost url with port is configured in your settings.local.yml

##### BGS
ssh -L 4447:localhost:4447 {{aws-url}}

##### EVSS
ssh -L 4431:localhost:4431 {{aws-url}}

## Testing
### Unit testing BGS service action wrappers
If using cassettes, make sure to only make or use ones under [spec/support/vcr_cassettes/claims_api](spec/support/vcr_cassettes/claims_api)
Check out documentation in comments for the spec helper `BGSClientSpecHelpers#use_bgs_cassette` and `BGSClientSpecHelpers#use_soap_cassette`

## OpenApi/Swagger Doc Generation
This api uses [rswag](https://github.com/rswag/rswag) to build the OpenApi/Swagger docs that are displayed in the [VA|Lighthouse APIs Documentation](https://developer.va.gov/explore/benefits/docs/claims?version=current).  To generate/update the docs for this api, navigate to the root directory of `vets-api` and run the following command ::
- `rake rswag:claims_api:build`

Documentation for v2 is now structured in an "environment layout", allowing us to preview documentation in our lower environments before releasing the updated `swagger.json` to the sandbox and production environments. v2 is now structured to include a `/dev` and `/production` file directory which will be served in the appropriate environments via the `v2/api_controller`.

To remove documentation for both environments, use the default `document: false` provided via rswag. To remove documentation from the production environment only, use `production: false`.

The implementation of `production: false` required additional changes to the [rswag_override](https://github.com/department-of-veterans-affairs/vets-api/blob/master/spec/rswag_override.rb) file. Due to this, the [rswag](https://github.com/rswag/rswag) repo should be checked periodically to update the `example_group_finished` method if needed.

## Seeds
Run `rake veteran:load_sample_vso_data ` to load Veteran organizations and a Veteran representative

## License
[CC0 1.0 Universal Summary](https://creativecommons.org/publicdomain/zero/1.0/legalcode).
