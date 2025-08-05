# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/responses/intent_to_files_response'

describe IntentToFileSerializer, type: :serializer do
  subject { serialize(itf_response, serializer_class: described_class) }

  let(:intent_to_file) { build_stubbed(:disability_compensation_intent_to_file) }
  let(:itf_response) { DisabilityCompensation::ApiProvider::IntentToFileResponse.new(intent_to_file:) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :intent_to_file' do
    expect(attributes['intent_to_file']).to be_present
  end

  it 'includes :intent_to_file with attributes' do
    expected_attributes = intent_to_file.attributes.keys.map(&:to_s)
    expect(attributes['intent_to_file'].keys).to match_array(expected_attributes)
  end
end
