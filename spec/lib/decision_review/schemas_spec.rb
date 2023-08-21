# frozen_string_literal: true

require 'rails_helper'
require 'decision_review/schemas'

shared_examples 'test schema' do
  it('JSON is valid') { expect(schema).to be_a Hash }
  it('JSON Schema is valid') { expect(validator).to be_truthy }
  it('fixture has no errors') { expect(errors).to be_empty }
end

describe DecisionReview::Schemas do
  def hash_from_json_file(*)
    JSON.parse File.read Rails.root.join(*)
  end

  let(:errors) { validator.validate(json).to_a }
  let(:validator) { JSONSchemer.schema(schema) }

  [
    [:NOD_CREATE_REQUEST, 'valid_NOD_create_request'],
    [:NOD_SHOW_RESPONSE_200, 'NOD_show_response_200'],
    [:NOD_CONTESTABLE_ISSUES_RESPONSE_200, 'NOD_contestable_issues_response_200']
  ].each do |(schema, fixture)|
    describe "::#{schema}" do
      let(:schema) { described_class.const_get schema }
      let(:json) { hash_from_json_file 'spec', 'fixtures', 'notice_of_disagreements', "#{fixture}.json" }

      include_examples 'test schema'
    end
  end

  describe '::NOD_CONTESTABLE_ISSUES_RESPONSE_200' do
    let(:schema) { described_class::NOD_CONTESTABLE_ISSUES_RESPONSE_200 }
    let(:json) do
      hash_from_json_file 'spec', 'fixtures', 'notice_of_disagreements', 'NOD_contestable_issues_response_200.json'
    end

    include_examples 'test schema'
  end
end
