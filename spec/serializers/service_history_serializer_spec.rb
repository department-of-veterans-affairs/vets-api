# frozen_string_literal: true

require 'rails_helper'

describe ServiceHistorySerializer, type: :serializer do
  subject { serialize(service_history, { serializer_class: described_class, is_collection: false }) }

  let(:service_history) do
    histories = {
      episodes: [build(:service_history, :with_deployments)],
      vet_status_eligibility: { confirmed: true, message: [] }
    }
    JSON.parse(histories.to_json, symbolize_names: true)
  end
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :service_history' do
    expect(attributes['service_history'].size).to eq service_history[:episodes].size
  end

  it 'includes :service_history with attributes' do
    expect(attributes['service_history'].first).to eq service_history[:episodes].first.deep_stringify_keys
  end
end
