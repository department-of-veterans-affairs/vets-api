# frozen_string_literal: true

require 'rails_helper'

describe TrackingSerializer, type: :serializer do
  subject { serialize(tracking, serializer_class: described_class) }

  let(:tracking) { build(:tracking, delivery_service: 'UPS') }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }
  let(:links) { data['links'] }

  it 'includes :id' do
    expect(data['id']).to eq tracking.tracking_number.to_s
  end

  it 'includes :type' do
    expect(data['type']).to eq 'trackings'
  end

  it 'includes :tracking_number' do
    expect(attributes['tracking_number']).to eq tracking.tracking_number
  end

  it 'includes :prescription_id' do
    expect(attributes['prescription_id']).to eq tracking.prescription_id
  end

  it 'includes :prescription_number' do
    expect(attributes['prescription_number']).to eq tracking.prescription_number
  end

  it 'includes :prescription_name' do
    expect(attributes['prescription_name']).to eq tracking.prescription_name
  end

  it 'includes :facility_name' do
    expect(attributes['facility_name']).to eq tracking.facility_name
  end

  it 'includes :rx_info_phone_number' do
    expect(attributes['rx_info_phone_number']).to eq tracking.rx_info_phone_number
  end

  it 'includes :ndc_number' do
    expect(attributes['ndc_number']).to eq tracking.ndc_number
  end

  it 'includes :shipped_date' do
    expect_time_eq(attributes['shipped_date'], tracking.shipped_date)
  end

  it 'includes :delivery_service' do
    expect(attributes['delivery_service']).to eq tracking.delivery_service
  end

  it 'includes :other_prescriptions' do
    expect(attributes['other_prescriptions']).to eq tracking.other_prescriptions
  end

  it 'includes :self link' do
    expected_url = v0_prescription_trackings_url(tracking.prescription_id)
    expect(links['self']).to eq expected_url
  end

  it 'includes :prescription link' do
    expected_url = v0_prescription_url(tracking.prescription_id)
    expect(links['prescription']).to eq expected_url
  end

  context 'when delivery service is UPS' do
    it 'includes :tracking_url link' do
      expected_url = "https://wwwapps.ups.com/WebTracking/track?track=yes&trackNums=#{tracking.tracking_number}"
      expect(links['tracking_url']).to eq expected_url
    end
  end

  context 'when delivery service is USPS' do
    let(:tracking) { build(:tracking, delivery_service: 'USPS') }

    it 'includes :tracking_url link' do
      expected_url = "https://tools.usps.com/go/TrackConfirmAction?tLabels=#{tracking.tracking_number}"
      expect(links['tracking_url']).to eq expected_url
    end
  end

  context 'when delivery service is else' do
    let(:tracking) { build(:tracking, delivery_service: 'DHL') }

    it 'includes :tracking_url link' do
      expected_url = ''
      expect(links['tracking_url']).to eq expected_url
    end
  end
end
