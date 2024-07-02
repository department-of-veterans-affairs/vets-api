# frozen_string_literal: true

require 'rails_helper'

describe MyHealth::V1::PrescriptionSerializer do
  let(:prescription) { build_stubbed(:prescription) }
  let(:rendered_hash) do
    ActiveModelSerializers::SerializableResource.new(prescription, { serializer: described_class }).as_json
  end
  let(:rendered_attributes) { rendered_hash[:data][:attributes] }

  it 'includes :prescription_id' do
    expect(rendered_attributes[:prescription_id]).to eq(prescription.prescription_id)
  end

  it 'includes :prescription_number' do
    expect(rendered_attributes[:prescription_number]).to eq(prescription.prescription_number)
  end

  it 'includes :prescription_name' do
    expect(rendered_attributes[:prescription_name]).to eq(prescription.prescription_name)
  end

  it 'includes :prescription_image' do
    expect(rendered_attributes[:prescription_image]).to eq(prescription.prescription_image)
  end

  it 'includes :refill_status' do
    expect(rendered_attributes[:refill_status]).to eq(prescription.refill_status)
  end

  it 'includes :refill_submit_date' do
    expected_date = prescription.refill_submit_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
    expect(rendered_attributes[:refill_submit_date]).to eq(expected_date)
  end

  it 'includes :refill_date' do
    expect(rendered_attributes[:refill_date]).to eq(prescription.refill_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes :refill_remaining' do
    expect(rendered_attributes[:refill_remaining]).to eq(prescription.refill_remaining)
  end

  it 'includes :ordered_date' do
    expect(rendered_attributes[:ordered_date]).to eq(prescription.ordered_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes :quantity' do
    expect(rendered_attributes[:quantity]).to eq(prescription.quantity)
  end

  it 'includes :expiration_date' do
    expect(rendered_attributes[:expiration_date]).to eq(prescription.expiration_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes :dispensed_date' do
    expect(rendered_attributes[:dispensed_date]).to eq(prescription.dispensed_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes :station_number' do
    expect(rendered_attributes[:station_number]).to eq(prescription.station_number)
  end

  it 'includes :is_refillable' do
    expect(rendered_attributes[:is_refillable]).to eq(prescription.is_refillable)
  end

  it 'includes :is_trackable' do
    expect(rendered_attributes[:is_trackable]).to eq(prescription.is_trackable)
  end

  it 'includes :self link' do
    expected_url = MyHealth::UrlHelper.new.v1_prescription_url(prescription.prescription_id)
    expect(rendered_hash[:data][:links][:self]).to eq expected_url
  end

  context 'when facility_api_name is present' do
    let(:prescription_with_api_name) { build_stubbed(:prescription, :with_api_name) }
    let(:rendered_hash_with_api_name) do
      ActiveModelSerializers::SerializableResource.new(prescription_with_api_name,
                                                       { serializer: described_class }).as_json
    end

    it 'includes :facility_name' do
      facility_name = rendered_hash_with_api_name[:data][:attributes][:facility_name]
      expect(facility_name).to eq(prescription_with_api_name.facility_api_name)
    end
  end

  context 'when facility_api_name is not present' do
    it 'includes :facility_name' do
      expect(rendered_attributes[:facility_name]).to eq(prescription.facility_name)
    end
  end

  context 'when prescription is trackable?' do
    let(:prescription_trackable) { build_stubbed(:prescription, is_trackable: true) }
    let(:rendered_hash_trackable) do
      ActiveModelSerializers::SerializableResource.new(prescription_trackable, { serializer: described_class }).as_json
    end

    it 'includes :tracking link' do
      expected_url = MyHealth::UrlHelper.new.v1_prescription_trackings_url(prescription_trackable.prescription_id)
      expect(rendered_hash_trackable[:data][:links][:tracking]).to eq expected_url
    end
  end

  context 'when prescription is not trackable?' do
    it 'includes :tracking link' do
      expect(rendered_hash[:data][:links][:tracking]).to be_nil
    end
  end
end
