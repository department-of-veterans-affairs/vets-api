# frozen_string_literal: true

require 'rails_helper'

describe '"NOD Create" Request Body JSON Schema (VA Form 10182)' do
  def hash_from_json_file(*path)
    JSON.parse File.read Rails.root.join(*path)
  end

  let(:json_schema) do
    hash_from_json_file 'lib', 'decision_review', 'schemas', 'NOD_create_request_body_schema.json'
  end
  let(:errors) { validator.validate(json).to_a }
  let(:json) { hash_from_json_file 'spec', 'fixtures', 'notice_of_disagreements', 'valid_NOD_create_request.json' }
  let(:validator) { JSONSchemer.schema(json_schema) }

  it('JSON is valid') { expect(json_schema).to be_a Hash }
  it('JSON Schema is valid') { expect(validator).to be_truthy }
  it('fixture has no errors') { expect(errors).to be_empty }
end
