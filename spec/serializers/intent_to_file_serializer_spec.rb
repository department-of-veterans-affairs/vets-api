# frozen_string_literal: true

require 'rails_helper'

describe IntentToFileSerializer, type: :serializer do
  # TODO: remove this file or update with LH response
  subject { serialize(intent_to_file_response, serializer_class: described_class) }

  let(:intent_to_file) { build_list(:evss_intent_to_file, 2) }
  let(:intent_to_file_response) do
    response = double('response', body: { intent_to_file: })
    EVSS::IntentToFile::IntentToFilesResponse.new(200, response)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :intent_to_file' do
    expect(attributes['intent_to_file'].size).to eq intent_to_file.size
  end

  it 'includes :intent_to_file with attributes' do
    expected_attributes = intent_to_file.first.attributes.keys.map(&:to_s)
    expect(attributes['intent_to_file'].first.keys).to eq expected_attributes
  end
end
