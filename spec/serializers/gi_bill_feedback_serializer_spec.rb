# frozen_string_literal: true

require 'rails_helper'

describe GIBillFeedbackSerializer, type: :serializer do
  subject { serialize(feedback, serializer_class: described_class) }

  let(:feedback) { build_stubbed(:gi_bill_feedback, :with_response) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq feedback.id
  end

  it 'includes :guid' do
    expect(attributes['guid']).to eq feedback.guid
  end

  it 'includes :state' do
    expect(attributes['state']).to eq feedback.state
  end

  it 'includes :parsed_response' do
    expect(attributes['parsed_response']).to eq feedback.parsed_response
  end
end
