# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe 'VA Form 10182 JSON Schema', type: :request do
  include SchemaHelpers
  include FixtureHelpers

  let(:json_schema) { read_schema '10182.json', 'decision_reviews', 'v2' }
  let(:validator) { JSONSchemer.schema(json_schema, ref_resolver: schema_ref_resolver) }
  let(:errors_invalid_issue_type) { validator.validate(json_invalid_issue_type).to_a }

  let(:json_appealable_issue) do
    fixture_as_json('decision_reviews/v2/valid_10182.json').tap do |payload|
      payload['included'][0]['type'] = 'appealableIssue'
    end
  end

  let(:json_invalid_issue_type) do
    fixture_as_json('decision_reviews/v2/valid_10182.json').tap do |payload|
      payload['included'][0]['type'] = 'invalidIssueType'
    end
  end

  it('accepts appealableIssue included type') do
    expect(validator.validate(json_appealable_issue).to_a).to be_empty
  end

  it('rejects invalid included type with included type enum error') do
    data_pointers = errors_invalid_issue_type.map { |error| error['data_pointer'] || error[:data_pointer] }
    error_types = errors_invalid_issue_type.map { |error| error['type'] || error[:type] }

    expect(data_pointers).to include('/included/0/type')
    expect(error_types).to include('enum')
  end
end
