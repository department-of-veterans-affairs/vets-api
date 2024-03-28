# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::V1::PrescriptionDetailsSerializer, type: :serializer do
  subject { serialize(prescription, serializer_class: described_class) }

  let(:prescription) { build(:prescription_details) }
  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes the prescription_id' do
    expect(attributes['prescription_id']).to eq(prescription.prescription_id)
  end

  it 'includes the refill_status' do
    expect(attributes['refill_status']).to eq(prescription.refill_status)
  end

  it 'includes the refill_date' do
    expect(attributes['refill_date']).to eq(prescription.refill_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes the refill_submit_date' do
    expect(attributes['refill_submit_date']).to eq(prescription.refill_submit_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes the refill_remaining' do
    expect(attributes['refill_remaining']).to eq(prescription.refill_remaining)
  end

  it 'includes the facility_name' do
    expect(attributes['facility_name']).to eq(prescription.facility_name)
  end

  it 'includes the ordered_date' do
    expect(attributes['ordered_date']).to eq(prescription.ordered_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes the quantity' do
    expect(attributes['quantity']).to eq(prescription.quantity)
  end

  it 'includes the expiration_date' do
    expect(attributes['expiration_date']).to eq(prescription.expiration_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes the prescription_number' do
    expect(attributes['prescription_number']).to eq(prescription.prescription_number)
  end

  it 'includes the prescription_name' do
    expect(attributes['prescription_name']).to eq(prescription.prescription_name)
  end

  it 'includes the dispensed_date' do
    expect(attributes['dispensed_date']).to eq(prescription.dispensed_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes the station_number' do
    expect(attributes['station_number']).to eq(prescription.station_number)
  end

  it 'includes the is_refillable' do
    expect(attributes['is_refillable']).to eq(prescription.is_refillable)
  end

  it 'includes the is_trackable' do
    expect(attributes['is_trackable']).to eq(prescription.is_trackable)
  end

  it 'includes the in_cerner_transition' do
    expect(attributes['in_cerner_transition']).to eq(prescription.in_cerner_transition)
  end

  it 'includes the not_refillable_display_message' do
    expect(attributes['not_refillable_display_message']).to eq(prescription.not_refillable_display_message)
  end

  it 'includes the cmop_ndc_number' do
    expect(attributes['cmop_ndc_number']).to eq(prescription.cmop_ndc_number)
  end

  it 'includes the sig' do
    expect(attributes['sig']).to eq(prescription.sig)
  end

  it 'includes the user_id' do
    expect(attributes['user_id']).to eq(prescription.user_id)
  end

  it 'includes the provider_first_name' do
    expect(attributes['provider_first_name']).to eq(prescription.provider_first_name)
  end

  it 'includes the provider_last_name' do
    expect(attributes['provider_last_name']).to eq(prescription.provider_last_name)
  end

  it 'includes the remarks' do
    expect(attributes['remarks']).to eq(prescription.remarks)
  end

  it 'includes the division_name' do
    expect(attributes['division_name']).to eq(prescription.division_name)
  end

  it 'includes the modified_date' do
    expect(attributes['modified_date']).to eq(prescription.modified_date.strftime('%Y-%m-%dT%H:%M:%S.%LZ'))
  end

  it 'includes the institution_id' do
    expect(attributes['institution_id']).to eq(prescription.institution_id)
  end

  it 'includes the dial_cmop_division_phone' do
    expect(attributes['dial_cmop_division_phone']).to eq(prescription.dial_cmop_division_phone)
  end

  it 'includes the disp_status' do
    expect(attributes['disp_status']).to eq(prescription.disp_status)
  end

  it 'includes the ndc' do
    expect(attributes['ndc']).to eq(prescription.ndc)
  end

  it 'includes the reason' do
    expect(attributes['reason']).to eq(prescription.reason)
  end

  it 'includes the prescription_number_index' do
    expect(attributes['prescription_number_index']).to eq(prescription.prescription_number_index)
  end

  it 'includes the prescription_source' do
    expect(attributes['prescription_source']).to eq(prescription.prescription_source)
  end

  it 'includes the disclaimer' do
    expect(attributes['disclaimer']).to eq(prescription.disclaimer)
  end

  it 'includes the indication_for_use' do
    expect(attributes['indication_for_use']).to eq(prescription.indication_for_use)
  end

  it 'includes the indication_for_use_flag' do
    expect(attributes['indication_for_use_flag']).to eq(prescription.indication_for_use_flag)
  end

  it 'includes the category' do
    expect(attributes['category']).to eq(prescription.category)
  end

  it 'includes the tracking' do
    expect(attributes['tracking']).to eq(prescription.tracking)
  end

  it 'includes the orderable_item' do
    expect(attributes['orderable_item']).to eq(prescription.orderable_item)
  end

  it 'includes the sorted_dispensed_date' do
    expect(attributes['sorted_dispensed_date']).to eq(prescription.sorted_dispensed_date.strftime('%Y-%m-%d'))
  end

  it 'includes the rx_rf_records' do
    expect(attributes['rx_rf_records']).to be_an(Array)
    expect(attributes['rx_rf_records']).to all(be_a(Hash))
    rx_rf_record = attributes['rx_rf_records'][0]
    expect(rx_rf_record['refill_status']).to eq('suspended')
    expect(rx_rf_record['refill_remaining']).to eq(4)
    expect(rx_rf_record['facility_name']).to eq('DAYT29')
    expect(rx_rf_record['is_refillable']).to eq(false)
    expect(rx_rf_record['is_trackable']).to eq(false)
    expect(rx_rf_record['prescription_id']).to eq(223_328_28)
    expect(rx_rf_record['sig']).to be_nil
    expect(rx_rf_record['quantity']).to be_nil
    expect(rx_rf_record['expiration_date']).to be_nil
    expect(rx_rf_record['prescription_number']).to eq('2720542')
    expect(rx_rf_record['prescription_name']).to eq('ONDANSETRON 8 MG TAB')
    expect(rx_rf_record['dispensed_date']).to eq('Thu, 21 Apr 2016 00:00:00 EDT')
    expect(rx_rf_record['station_number']).to eq('989')
    expect(rx_rf_record['in_cerner_transition']).to eq(false)
    expect(rx_rf_record['not_refillable_display_message']).to be_nil
    expect(rx_rf_record['cmop_division_phone']).to be_nil
    expect(rx_rf_record['cmop_ndc_number']).to be_nil
    expect(rx_rf_record['id']).to eq(223_328_28)
    expect(rx_rf_record['user_id']).to eq(169_559_36)
    expect(rx_rf_record['provider_first_name']).to be_nil
    expect(rx_rf_record['provider_last_name']).to be_nil
    expect(rx_rf_record['remarks']).to be_nil
    expect(rx_rf_record['division_name']).to be_nil
    expect(rx_rf_record['modified_date']).to be_nil
    expect(rx_rf_record['institution_id']).to be_nil
    expect(rx_rf_record['dial_cmop_division_phone']).to eq('')
    expect(rx_rf_record['disp_status']).to eq('Suspended')
    expect(rx_rf_record['ndc']).to be_nil
    expect(rx_rf_record['reason']).to be_nil
    expect(rx_rf_record['prescription_number_index']).to eq('RF1')
    expect(rx_rf_record['prescription_source']).to eq('RF')
    expect(rx_rf_record['disclaimer']).to be_nil
    expect(rx_rf_record['indication_for_use']).to be_nil
    expect(rx_rf_record['indication_for_use_flag']).to be_nil
    expect(rx_rf_record['category']).to eq('Rx Medication')
    expect(rx_rf_record['tracking_list']).to be_nil
    expect(rx_rf_record['rx_rf_records']).to be_nil
    expect(rx_rf_record['tracking']).to eq(false)
  end

  it 'includes the tracking_list records as an array' do
    tracking_list = attributes['tracking_list']
    expect(tracking_list).to be_an(Array)
    tracking_item = tracking_list[0]
    expect(tracking_item).to be_a(Hash)
    expect(tracking_list[0]).to include({ 'carrier' => 'UPS', 'complete_date_time' => '2023-03-28T04:39:11-04:00' })
  end

  it 'includes the tracking_list records as an array' do
    tracking_list = attributes['tracking_list']
    expect(tracking_list).to be_an(Array)
    tracking_item = tracking_list[0]
    expect(tracking_item).to be_a(Hash)
    expect(tracking_list[0]).to include({ 'carrier' => 'UPS', 'complete_date_time' => '2023-03-28T04:39:11-04:00' })
  end
end
