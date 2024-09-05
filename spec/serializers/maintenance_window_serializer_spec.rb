# frozen_string_literal: true

require 'rails_helper'

describe MaintenanceWindowSerializer, type: :serializer do
  subject { serialize(maintenance_window, serializer_class: described_class) }

  let(:maintenance_window) { build_stubbed(:maintenance_window) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq maintenance_window.id.to_s
  end

  it 'includes :external_service' do
    expect(attributes['external_service']).to eq maintenance_window.external_service
  end

  it 'includes :start_time' do
    expect_time_eq(attributes['start_time'], maintenance_window.start_time)
  end

  it 'includes :end_time' do
    expect_time_eq(attributes['end_time'], maintenance_window.end_time)
  end

  it 'includes :description' do
    expect(attributes['description']).to eq maintenance_window.description
  end
end
