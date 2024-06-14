# frozen_string_literal: true

require 'rails_helper'

describe BackendStatusSerializer do
  subject { serialize(backend_status, serializer_class: described_class) }

  let(:backend_status) { build_stubbed(:backend_status) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to be_blank
  end

  it 'includes :name' do
    expect(attributes['name']).to eq backend_status.name
  end

  it 'includes :service_id' do
    expect(attributes['service_id']).to eq backend_status.service_id
  end

  it 'includes :is_available' do
    expect(attributes['is_available']).to eq backend_status.is_available
  end

  it 'includes :uptime_remaining' do
    expect(attributes['uptime_remaining']).to eq backend_status.uptime_remaining
  end
end
