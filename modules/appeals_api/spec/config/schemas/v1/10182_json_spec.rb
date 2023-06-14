# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe 'VA Form 10182 JSON Schema', type: :request do
  include SchemaHelpers
  include FixtureHelpers

  let(:json_schema) { read_schema '10182.json', 'decision_reviews', 'v1' }
  let(:errors) { validator.validate(json).to_a }
  let(:json) { fixture_as_json 'decision_reviews/v1/valid_10182.json' }
  let(:validator) { JSONSchemer.schema(json_schema) }

  it('JSON is valid') { expect(json_schema).to be_a Hash }

  it('JSON Schema is valid') { expect(validator).to be_truthy }

  it('fixture has no errors') { expect(errors).to be_empty }
end
