# frozen_string_literal: true

require 'rails_helper'
require 'va_facilities/csv_serializer'

RSpec.describe VaFacilities::CsvSerializer do
  let(:vha_facility) { build :vha_648A4 }
  let(:vba_facility) { build :vba_314c }
  let(:vc_facility) { build :vc_0543V }
  let(:nca_facility) { build :nca_888 }

  def compare_row_to_facility(row, facility)
    expect(row['id']).to eq([facility.facility_type_prefix, facility.unique_id].join('_'))
    expect(row['name']).to eq(facility.name)
    expect(row['station_id']).to eq(facility.unique_id)
    expect(row['latitude'].to_f).to eq(facility.lat)
    expect(row['longitude'].to_f).to eq(facility.long)
    expect(row['facility_type']).to eq(facility.facility_type)
    expect(row['classification']).to eq(facility.classification)
    expect(row['website']).to eq(facility.website)
    expect(row['mobile'].to_s).to eq(facility.mobile.to_s)
    expect(row['active_status']).to eq(facility.active_status)

    expect(row['physical_address_1']).to eq(facility.address['physical']['address_1'])
    expect(row['physical_address_2']).to eq(facility.address['physical']['address_2'])
    expect(row['physical_address_3']).to eq(facility.address['physical']['address_3'])
    expect(row['physical_city']).to eq(facility.address['physical']['city'])
    expect(row['physical_state']).to eq(facility.address['physical']['state'])
    expect(row['physical_zip']).to eq(facility.address['physical']['zip'])

    expect(row['mailing_address_1']).to eq(facility.address['mailing']['address_1'])
    expect(row['mailing_address_2']).to eq(facility.address['mailing']['address_2'])
    expect(row['mailing_address_3']).to eq(facility.address['mailing']['address_3'])
    expect(row['mailing_city']).to eq(facility.address['mailing']['city'])
    expect(row['mailing_state']).to eq(facility.address['mailing']['state'])
    expect(row['mailing_zip']).to eq(facility.address['mailing']['zip'])

    expect(row['phone_main']).to eq(facility.phone['main'])
    expect(row['phone_fax']).to eq(facility.phone['fax'])
    expect(row['phone_mental_health_clinic']).to eq(facility.phone['mental_health_clinic'])
    expect(row['phone_pharmacy']).to eq(facility.phone['pharmacy'])
    expect(row['phone_after_hours']).to eq(facility.phone['after_hours'])
    expect(row['phone_patient_advocate']).to eq(facility.phone['patient_advocate'])
    expect(row['phone_enrollment_coordinator']).to eq(facility.phone['enrollment_coordinator'])
  end

  def compare_facility_hours(row, facility)
    expect(row['hours_monday']).to eq(facility.hours['Monday'])
    expect(row['hours_tuesday']).to eq(facility.hours['Tuesday'])
    expect(row['hours_wednesday']).to eq(facility.hours['Wednesday'])
    expect(row['hours_thursday']).to eq(facility.hours['Thursday'])
    expect(row['hours_friday']).to eq(facility.hours['Friday'])
    expect(row['hours_saturday']).to eq(facility.hours['Saturday'])
    expect(row['hours_sunday']).to eq(facility.hours['Sunday'])
  end

  def compare_vc_facility_hours(row, facility)
    expect(row['hours_monday']).to eq(facility.hours['monday'])
    expect(row['hours_tuesday']).to eq(facility.hours['tuesday'])
    expect(row['hours_wednesday']).to eq(facility.hours['wednesday'])
    expect(row['hours_thursday']).to eq(facility.hours['thursday'])
    expect(row['hours_friday']).to eq(facility.hours['friday'])
    expect(row['hours_saturday']).to eq(facility.hours['saturday'])
    expect(row['hours_sunday']).to eq(facility.hours['sunday'])
  end

  it 'uses preset headers' do
    facilities_csv = VaFacilities::CsvSerializer.to_csv([vha_facility])
    data = CSV.parse(facilities_csv, headers: true)

    expect(data.headers).to eq(VaFacilities::CsvSerializer.headers)
  end

  it 'converts a vha facility object to a csv' do
    facilities_csv = VaFacilities::CsvSerializer.to_csv([vha_facility])
    data = CSV.parse(facilities_csv, headers: true)

    compare_row_to_facility(data[0], vha_facility)
    compare_facility_hours(data[0], vha_facility)
  end

  it 'converts a vba facility object to a csv' do
    facilities_csv = VaFacilities::CsvSerializer.to_csv([vba_facility])
    data = CSV.parse(facilities_csv, headers: true)

    compare_row_to_facility(data[0], vba_facility)
    compare_facility_hours(data[0], vba_facility)
  end

  it 'converts a vc facility object to a csv' do
    facilities_csv = VaFacilities::CsvSerializer.to_csv([vc_facility])
    data = CSV.parse(facilities_csv, headers: true)

    compare_row_to_facility(data[0], vc_facility)
    compare_vc_facility_hours(data[0], vc_facility)
  end

  it 'converts a nca facility object to a csv' do
    facilities_csv = VaFacilities::CsvSerializer.to_csv([nca_facility])
    data = CSV.parse(facilities_csv, headers: true)

    compare_row_to_facility(data[0], nca_facility)
    compare_facility_hours(data[0], nca_facility)
  end
end
