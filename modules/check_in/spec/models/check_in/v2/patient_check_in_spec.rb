# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::PatientCheckIn do
  subject { described_class }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:patient_check_in) { subject.build }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)

    Rails.cache.clear
  end

  describe '.build' do
    it 'returns an instance of PatientCheckIn' do
      expect(patient_check_in).to be_an_instance_of(CheckIn::V2::PatientCheckIn)
    end
  end

  describe 'attributes' do
    it 'responds to check_in' do
      expect(patient_check_in.respond_to?(:check_in)).to be(true)
    end

    it 'responds to data' do
      expect(patient_check_in.respond_to?(:data)).to be(true)
    end

    it 'responds to settings' do
      expect(patient_check_in.respond_to?(:settings)).to be(true)
    end

    it 'gets redis_session_prefix from settings' do
      expect(patient_check_in.redis_session_prefix).to eq('check_in_lorota_v2')
    end

    it 'gets redis_token_expiry from settings' do
      expect(patient_check_in.redis_token_expiry).to eq(43_200)
    end
  end

  describe 'check_in_type' do
    let(:uuid) { Faker::Internet.uuid }
    let(:check_in) { double('Session', uuid:, check_in_type: 'preCheckIn') }

    it 'delegates check_in_type to check_in' do
      patient_check_in = subject.build(check_in:)

      expect(patient_check_in.check_in_type).to eq('preCheckIn')
    end
  end

  describe '#unauthorized_message' do
    let(:uuid) { Faker::Internet.uuid }
    let(:check_in) { double('Session', uuid:) }
    let(:data) { double('FaradayResponse', status: 200, body: {}) }
    let(:resp) { { permissions: 'read.none', status: 'success', uuid: } }

    it 'returns a hashed response' do
      patient_check_in_with_data = subject.build(data:, check_in:)

      expect(patient_check_in_with_data.unauthorized_message).to eq(resp)
    end
  end

  describe '#error_status?' do
    let(:data) { double('FaradayResponse', status: 401, body: {}) }

    it 'returns true' do
      patient_check_in_with_data = subject.build(data:, check_in: nil)

      expect(patient_check_in_with_data.error_status?).to eq(true)
    end
  end

  describe '#error_message' do
    let(:uuid) { Faker::Internet.uuid }
    let(:check_in) { double('Session', uuid:) }
    let(:data) { double('FaradayResponse', status: 403, body: { error: 'forbidden' }.to_json) }
    let(:resp) { { error: true, message: { 'error' => 'forbidden' }, status: 403 } }

    it 'returns an error message' do
      patient_check_in_with_data = subject.build(data:, check_in: nil)

      expect(patient_check_in_with_data.error_message).to eq(resp)
    end
  end

  describe '#save' do
    let(:uuid) { Faker::Internet.uuid }
    let(:check_in) { double('Session', uuid:) }
    let(:next_of_kin1) do
      {
        'name' => 'Joe',
        'workPhone' => '564-438-5739',
        'relationship' => 'Brother',
        'phone' => '738-573-2849',
        'address' => {
          'street1' => '432 Horner Street',
          'street2' => 'Apt 53',
          'street3' => '',
          'city' => 'Akron',
          'county' => 'OH',
          'state' => 'OH',
          'zip' => '44308',
          'zip4' => '4252',
          'country' => 'USA'
        }
      }
    end
    let(:emergency_contact) do
      {
        'name' => 'Michael',
        'relationship' => 'Spouse',
        'phone' => '415-322-9968',
        'workPhone' => '630-835-1623',
        'address' => {
          'street1' => '3008 Millbrook Road',
          'street2' => '',
          'street3' => '',
          'city' => 'Wheeling',
          'county' => 'IL',
          'state' => 'IL',
          'zip' => '60090',
          'zip4' => '7241',
          'country' => 'USA'
        }
      }
    end
    let(:mailing_address) do
      {
        'street1' => '1025 Meadowbrook Mall Road',
        'street2' => '',
        'street3' => '',
        'city' => 'Beverly Hills',
        'county' => 'Los Angeles',
        'state' => 'CA',
        'zip' => '60090',
        'zip4' => nil,
        'country' => 'USA'
      }
    end
    let(:home_address) do
      {
        'street1' => '3899 Southside Lane',
        'street2' => '',
        'street3' => '',
        'city' => 'Los Angeles',
        'county' => 'Los Angeles',
        'state' => 'CA',
        'zip' => '90017',
        'zip4' => nil,
        'country' => 'USA'
      }
    end
    let(:home_phone) { '323-743-2569' }
    let(:mobile_phone) { '323-896-8512' }
    let(:work_phone) { '909-992-3911' }
    let(:patient_cell_phone) { '919-972-4921' }
    let(:email_address) { 'utilside@goggleappsmail.com' }
    let(:demographics) do
      {
        'nextOfKin1' => next_of_kin1,
        'emergencyContact' => emergency_contact,
        'mailingAddress' => mailing_address,
        'homeAddress' => home_address,
        'homePhone' => home_phone,
        'mobilePhone' => mobile_phone,
        'workPhone' => work_phone,
        'emailAddress' => email_address,
        'icn' => '2113957154V785237'
      }
    end
    let(:appointment1) do
      {
        'appointmentIEN' => '460',
        'patientDFN' => '2345',
        'checkedInTime' => '',
        'checkInSteps' => {},
        'checkInWindowEnd' => '2021-12-23T08:40:00.000-05:00',
        'checkInWindowStart' => '2021-12-23T08:00:00.000-05:00',
        'clinicCreditStopCodeName' => 'SOCIAL WORK SERVICE',
        'clinicFriendlyName' => 'Health Wellness',
        'clinicIen' => 500,
        'clinicLocation' => 'ATLANTA VAMC',
        'clinicName' => 'Family Wellness',
        'clinicPhoneNumber' => '555-555-5555',
        'clinicStopCodeName' => 'PRIMARY CARE/MEDICINE',
        'doctorName' => '',
        'eligibility' => 'ELIGIBLE',
        'facility' => 'VEHU DIVISION',
        'kind' => 'clinic',
        'startTime' => '2021-12-23T08:30:00',
        'stationNo' => 500,
        'status' => ''
      }
    end
    let(:patient_demographic_status) do
      {
        'demographicsNeedsUpdate' => true,
        'demographicsConfirmedAt' => nil,
        'nextOfKinNeedsUpdate' => false,
        'nextOfKinConfirmedAt' => '2021-12-10T05:15:00.000-05:00',
        'emergencyContactNeedsUpdate' => true,
        'emergencyContactConfirmedAt' => '2021-12-10T05:30:00.000-05:00'
      }
    end

    let(:patient_data) do
      {
        id: uuid,
        payload: {
          demographics:,
          appointments: [appointment1],
          patientDemographicsStatus: patient_demographic_status,
          patientCellPhone: patient_cell_phone
        }
      }
    end
    let(:appointment_data) do
      {
        data: {
          id: uuid,
          type: :appointment_identifier,
          attributes: {
            patientDFN: '2345',
            stationNo: 500,
            appointmentIEN: '460',
            icn: '2113957154V785237',
            mobilePhone: mobile_phone,
            patientCellPhone: patient_cell_phone
          }
        }
      }
    end

    let(:data) { double('FaradayResponse', status: 200, body: patient_data.to_json) }

    it 'returns a hashed response' do
      patient_check_in_with_data = subject.build(data:, check_in:)
      patient_check_in_with_data.save

      cached_appointment_data = Rails.cache.read(
        "check_in_lorota_v2_appointment_identifiers_#{uuid}",
        namespace: 'check-in-lorota-v2-cache'
      )

      expect(Oj.load(cached_appointment_data)).to eq(appointment_data)
    end
  end
end
