# frozen_string_literal: true

require 'rails_helper'

describe ExtractStatusSerializer, type: :serializer do
  subject { serialize(extract_status, serializer_class: described_class) }

  let(:extract_status) { build_stubbed(:extract_status) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq extract_status.id
  end

  it 'includes :type' do
    expect(data['type']).to eq 'extract_statuses'
  end

  it 'includes :extract_type' do
    expect(attributes['extract_type']).to eq extract_status.extract_type
  end

  it 'includes :last_updated' do
    expect_time_eq(attributes['last_updated'], extract_status.last_updated)
  end

  it 'includes :status' do
    expect(attributes['status']).to eq extract_status.status
  end

  it 'includes :created_on' do
    expect_time_eq(attributes['created_on'], extract_status.created_on)
  end

  it 'includes :station_number' do
    expect(attributes['station_number']).to eq extract_status.station_number
  end
end
