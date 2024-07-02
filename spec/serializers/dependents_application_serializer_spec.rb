# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsApplicationSerializer, type: :serializer do
  subject { serialize(application, serializer_class: described_class) }

  let(:application) { build_stubbed(:dependents_application, :with_response) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq application.id
  end

  it 'includes :guid' do
    expect(attributes['guid']).to eq application.guid
  end

  it 'includes :state' do
    expect(attributes['state']).to eq application.state
  end

  it 'includes :parsed_response' do
    expect(attributes['parsed_response']).to eq application.parsed_response
  end
end
