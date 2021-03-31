# frozen_string_literal: true

require 'rails_helper'
require 'decision_review/schemas'

shared_examples 'test schema' do
  it('JSON is valid') { expect(schema).to be_a Hash }
  it('JSON Schema is valid') { expect(validator).to be_truthy }
  it('fixture has no errors') { expect(errors).to be_empty }
end

describe DecisionReview::Schemas do
  def hash_from_json_file(*path)
    JSON.parse File.read Rails.root.join(*path)
  end

  let(:errors) { validator.validate(json).to_a }
  let(:validator) { JSONSchemer.schema(schema) }

  describe '::NOD_CREATE_REQUEST' do
    let(:schema) { described_class::NOD_CREATE_REQUEST }
    let(:json) { hash_from_json_file 'spec', 'fixtures', 'notice_of_disagreements', 'valid_NOD_create_request.json' }

    include_examples 'test schema'
  end

  describe '::NOD_SHOW_RESPONSE_200' do
    let(:schema) { described_class::NOD_SHOW_RESPONSE_200 }
    let(:json) { hash_from_json_file 'spec', 'fixtures', 'notice_of_disagreements', 'NOD_show_response_200.json' }

    include_examples 'test schema'
  end

  describe '::NOD_CONTESTABLE_ISSUES_RESPONSE_200' do
    let(:schema) { described_class::NOD_CONTESTABLE_ISSUES_RESPONSE_200 }
    let(:json) do
      hash_from_json_file 'spec', 'fixtures', 'notice_of_disagreements', 'NOD_contestable_issues_response_200.json'
    end

    include_examples 'test schema'
  end
end
