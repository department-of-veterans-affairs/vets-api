# frozen_string_literal: true

require 'rails_helper'

describe PrescriptionSerializer do
  subject { serialize(prescription, serializer_class: described_class) }

  let(:prescription) { build_stubbed(:prescription) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to eq(prescription.prescription_id.to_s)
  end

  it 'includes :type' do
    expect(data['type']).to eq('prescriptions')
  end

  it 'includes :prescription_id' do
    expect(attributes['prescription_id']).to eq(prescription.prescription_id)
  end

  it 'includes :prescription_number' do
    expect(attributes['prescription_number']).to eq(prescription.prescription_number)
  end

  it 'includes :prescription_name' do
    expect(attributes['prescription_name']).to eq(prescription.prescription_name)
  end

  it 'includes :prescription_image' do
    expect(attributes['prescription_image']).to eq(prescription.prescription_image)
  end

  it 'includes :refill_status' do
    expect(attributes['refill_status']).to eq(prescription.refill_status)
  end

  it 'includes :refill_submit_date' do
    expected_date = prescription.refill_submit_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ')
    expect(attributes['refill_submit_date']).to eq(expected_date)
  end

  it 'includes :refill_date' do
    expect(attributes['refill_date']).to eq(prescription.refill_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes :refill_remaining' do
    expect(attributes['refill_remaining']).to eq(prescription.refill_remaining)
  end

  it 'includes :ordered_date' do
    expect(attributes['ordered_date']).to eq(prescription.ordered_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes :quantity' do
    expect(attributes['quantity']).to eq(prescription.quantity)
  end

  it 'includes :expiration_date' do
    expect(attributes['expiration_date']).to eq(prescription.expiration_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes :dispensed_date' do
    expect(attributes['dispensed_date']).to eq(prescription.dispensed_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes :station_number' do
    expect(attributes['station_number']).to eq(prescription.station_number)
  end

  it 'includes :is_refillable' do
    expect(attributes['is_refillable']).to eq(prescription.is_refillable)
  end

  it 'includes :is_trackable' do
    expect(attributes['is_trackable']).to eq(prescription.is_trackable)
  end

  it 'includes :self link' do
    expected_url = v0_prescription_url(prescription.prescription_id)
    expect(links['self']).to eq expected_url
  end

  it 'includes :facility_name' do
    expect(attributes['facility_name']).to eq(prescription.facility_name)
  end

  context 'when prescription is trackable?' do
    let(:prescription) { build_stubbed(:prescription, is_trackable: true) }

    it 'includes :tracking link' do
      expected_url = v0_prescription_trackings_url(prescription.prescription_id)
      expect(links['tracking']).to eq expected_url
    end
  end

  context 'when prescription is not trackable?' do
    it 'includes :tracking link' do
      expect(links['tracking']).to be_blank
    end
  end
end
