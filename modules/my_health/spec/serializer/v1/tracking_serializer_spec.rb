# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::TrackingSerializer do
  let(:tracking) { build(:tracking) }

  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(tracking, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :id' do
    expect(rendered_hash[:data][:id]).to eq tracking.tracking_number.to_s
  end

  it 'includes :tracking_number' do
    expect(rendered_attributes[:tracking_number]).to eq tracking.tracking_number
  end

  it 'includes :prescription_id' do
    expect(rendered_attributes[:prescription_id]).to eq tracking.prescription_id
  end

  it 'includes :prescription_number' do
    expect(rendered_attributes[:prescription_number]).to eq tracking.prescription_number
  end

  it 'includes :prescription_name' do
    expect(rendered_attributes[:prescription_name]).to eq tracking.prescription_name
  end

  it 'includes :facility_name' do
    expect(rendered_attributes[:facility_name]).to eq tracking.facility_name
  end

  it 'includes :rx_info_phone_number' do
    expect(rendered_attributes[:rx_info_phone_number]).to eq tracking.rx_info_phone_number
  end

  it 'includes :ndc_number' do
    expect(rendered_attributes[:ndc_number]).to eq tracking.ndc_number
  end

  it 'includes :shipped_date' do
    expect(rendered_attributes[:shipped_date]).to eq tracking.shipped_date
  end

  it 'includes :delivery_service' do
    expect(rendered_attributes[:delivery_service]).to eq tracking.delivery_service
  end

  it 'includes :other_prescriptions' do
    expect(rendered_attributes[:other_prescriptions]).to eq tracking.other_prescriptions
  end

  context 'when delivery service is UPS' do
    it 'includes :tracking_url link' do
      expected_url = "https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=#{tracking.tracking_number}"
      expect(rendered_hash[:data][:links][:tracking_url]).to eq expected_url
    end
  end

  context 'when delivery service is USPS' do
    let(:tracking_usps) { build(:tracking, delivery_service: 'USPS') }
    let(:rendered_hash_usps) do
      ActiveModelSerializers::SerializableResource.new(tracking_usps, { serializer: described_class }).as_json
    end

    it 'includes :tracking_url link' do
      expected_url = "https://tools.usps.com/go/TrackConfirmAction?tLabels=#{tracking.tracking_number}"
      expect(rendered_hash_usps[:data][:links][:tracking_url]).to eq expected_url
    end
  end

  context 'when delivery service is else' do
    let(:tracking_dhl) { build(:tracking, delivery_service: 'DHL') }
    let(:rendered_hash_dhl) do
      ActiveModelSerializers::SerializableResource.new(tracking_dhl, { serializer: described_class }).as_json
    end

    it 'includes :tracking_url link' do
      expected_url = ''
      expect(rendered_hash_dhl[:data][:links][:tracking_url]).to eq expected_url
    end
  end
end
