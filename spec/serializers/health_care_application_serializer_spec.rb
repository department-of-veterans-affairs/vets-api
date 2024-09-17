# frozen_string_literal: true

require 'rails_helper'

describe HealthCareApplicationSerializer, type: :serializer do
  subject { serialize(application, serializer_class: described_class) }

  let(:application) { build_stubbed(:health_care_application, :with_success) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq application.id.to_s
  end

  it 'includes :type' do
    expect(data['type']).to eq 'health_care_applications'
  end

  it 'includes :state' do
    expect(attributes['state']).to eq application.state
  end

  it 'includes :form_submission_id' do
    expect(attributes['form_submission_id']).to eq application.form_submission_id
  end

  it 'includes :timestamp' do
    expect(attributes['timestamp']).to eq application.timestamp
  end
end
