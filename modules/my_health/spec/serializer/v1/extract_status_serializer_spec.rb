# frozen_string_literal: true

require 'rails_helper'
require 'bb/generate_report_request_form'

describe MyHealth::V1::ExtractStatusSerializer do
  let(:extract_status) { build(:extract_status) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(extract_status, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq extract_status.id
  end

  it 'includes :extract_type' do
    expect(rendered_attributes[:extract_type]).to eq extract_status.extract_type
  end

  it 'includes :last_updated' do
    expect(rendered_attributes[:last_updated]).to eq extract_status.last_updated
  end

  it 'includes :status' do
    expect(rendered_attributes[:status]).to eq extract_status.status
  end

  it 'includes :created_on' do
    expect(rendered_attributes[:created_on]).to eq extract_status.created_on
  end

  it 'includes :station_number' do
    expect(rendered_attributes[:station_number]).to eq extract_status.station_number
  end
end
