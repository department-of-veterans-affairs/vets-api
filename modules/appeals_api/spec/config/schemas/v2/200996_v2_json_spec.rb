# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe 'VA Form 20-0996 JSON Schema', type: :request do
  include SchemaHelpers
  include FixtureHelpers

  let(:json_schema) { read_schema '200996.json', 'decision_reviews', 'v2' }

  let(:errors) { validator.validate(json).to_a }
  let(:errors_minimal) { validator.validate(json_minimal).to_a }
  let(:errors_extra) { validator.validate(json_extra).to_a }
  let(:json) { fixture_as_json 'decision_reviews/v2/valid_200996.json' }
  let(:json_minimal) { fixture_as_json 'decision_reviews/v2/valid_200996_minimum.json' }
  let(:json_extra) { fixture_as_json 'decision_reviews/v2/valid_200996_extra.json' }
  let(:validator) { JSONSchemer.schema(json_schema, ref_resolver: schema_ref_resolver) }

  it('JSON is valid') { expect(json_schema).to be_a Hash }

  it('JSON Schema is valid') { expect(validator).to be_truthy }

  it('basic fixture has no errors') { expect(errors).to be_empty }

  it('minimal fixture has no errors') { expect(errors_minimal).to be_empty }

  it('extra fixture has no errors') { expect(errors_extra).to be_empty }
end
