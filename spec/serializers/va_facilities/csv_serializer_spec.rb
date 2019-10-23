# frozen_string_literal: true

require 'rails_helper'
require 'va_facilities/csv_serializer'

RSpec.describe VaFacilities::CsvSerializer do
  let(:vha_facility) { build :vha_648A4 }
  let(:vba_facility) { build :vba_314c }
  let(:vc_facility) { build :vc_0543V }
  let(:nca_facility) { build :nca_888 }

  def compare_row_to_facility(row, facility)
    compare_simple_keys(row, facility)

    compare_phone(row, facility)
    compare_address('physical', row, facility)
    compare_address('mailing', row, facility)

    expect(row['id']).to eq([facility.facility_type_prefix, facility.unique_id].join('_'))
    expect(row['station_id']).to eq(facility.unique_id)
    expect(row['latitude'].to_f).to eq(facility.lat)
    expect(row['longitude'].to_f).to eq(facility.long)
    expect(row['mobile'].to_s).to eq(facility.mobile.to_s)
  end

  def compare_simple_keys(row, facility)
    simple_keys = %w[
      name
      facility_type
      classification
      website
      active_status
    ]

    simple_keys.each do |key|
      expect(row[key]).to eq facility.send(key.to_sym)
    end
  end

  def compare_phone(row, facility)
    phone_keys = %w[
      main
      fax
      mental_health_clinic
      pharmacy
      after_hours
      patient_advocate
      enrollment_coordinator
    ]

    phone_keys.each do |key|
      expect(row["phone_#{key}"]).to eq(facility.phone[key])
    end
  end

  def compare_address(address_type, row, facility)
    address_keys = %w[
      address_1
      address_2
      address_3
      city
      state
      zip
    ]

    address_keys.each do |addr_key|
      expect(row["#{address_type}_#{addr_key}"]).to eq(facility.address[address_type][addr_key])
    end
  end

  def compare_facility_hours(row, facility)
    capitalized_days = %w[
      Monday
      Tuesday
      Wednesday
      Thursday
      Friday
      Saturday
      Sunday
    ]

    capitalized_days.each do |day|
      expect(row["hours_#{day.downcase}"]).to eq(facility.hours[day])
    end
  end

  def compare_vc_facility_hours(row, facility)
    vc_days = %w[
      monday
      tuesday
      wednesday
      thursday
      friday
      saturday
      sunday
    ]

    vc_days.each do |day|
      expect(row["hours_#{day}"]).to eq(facility.hours[day])
    end
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
