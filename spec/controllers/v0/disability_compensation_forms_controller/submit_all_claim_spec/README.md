# `#submit_all_claim` controller spec
This is an end-to-end spec of `POST /v0/disability_compensation_form/submit_all_claim`. It ensures that given inputs, payloads from the frontend, produce expected outputs, payloads to services upstream.

As a controller spec that has Sidekiq's `inline` testing mode enabled, this spec achieves full coverage of the many layers of transformation that occur between inputs and outputs.

## Input
Inputs are the form 526 payloads we submit from the frontend. The spec example author supplies them at `spec/support/disability_compensation_form/submit_all_claim/<fixture>.json`.

## Output
Outputs are the resulting HTTP interactions with a variety of upstream services. One spec example records all of those HTTP interactions to a single VCR cassette at `spec/support/vcr_cassettes/disability_compensation_form/submit_all_claim/<example>.yml`. Remember to consider redaction of sensitive values.

## Helper
Spec examples are authored using the `define_example` helper method.

### 1 example : 1 cassette
This helper applies different VCR request matching logic per upstream endpoint. This is what enables us to record _all_ HTTP interactions that occur within a spec example to just a _single_ cassette. The exact same per-endpoint request matching logic is applicable across all spec examples.

That logic is registered at
`spec/controllers/v0/disability_compensation_forms_controller/submit_all_claim_spec/vcr_endpoint_matchers.rb`. It should be at least as strict as is needed to genuinely exercise everything that needs exercising. In other words, we want to avoid the VCR cheating we've engaged in thus far, because it prevents us from automatically noticing regressions that break the form 526 application.

### Parameters
Documented in `spec/controllers/v0/disability_compensation_forms_controller/submit_all_claim_spec/example_definition.rb`.
