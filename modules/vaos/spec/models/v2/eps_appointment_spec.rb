# frozen_string_literal: true

# spec/serializers/vaos/v2/eps_appointment_spec.rb
require 'rails_helper'

describe VAOS::V2::EpsAppointment do
  subject { described_class.new(params) }

  let(:params) do
    {
      id: 1,
      appointment_details: { status: 'booked', last_retrieved: '2023-10-01T00:00:00Z', start: '2023-10-10T10:00:00Z' },
      referral: { referral_number: '12345' },
      patient_id: '1234567890V123456',
      network_id: 'network_1',
      provider_service_id: 'clinic_1',
      contact: 'contact_info'
    }
  end

  describe '#initialize' do
    it 'initializes with correct attributes' do
      expect(subject.instance_variable_get(:@id)).to eq('1')
      expect(subject.instance_variable_get(:@status)).to eq('booked')
      expect(subject.instance_variable_get(:@patient_icn)).to eq('1234567890V123456')
      expect(subject.instance_variable_get(:@created)).to eq('2023-10-01T00:00:00Z')
      expect(subject.instance_variable_get(:@location_id)).to eq('network_1')
      expect(subject.instance_variable_get(:@clinic)).to eq('clinic_1')
      expect(subject.instance_variable_get(:@start)).to eq('2023-10-10T10:00:00Z')
      expect(subject.instance_variable_get(:@contact)).to eq('contact_info')
      expect(subject.instance_variable_get(:@referral_id)).to eq('12345')
      expect(subject.instance_variable_get(:@referral)).to eq({ referral_number: '12345' })
    end
  end

  describe '#serializable_hash' do
    it 'returns a hash with the correct attributes including derived fields' do
      Timecop.freeze(Time.zone.parse('2023-10-10T12:00:00Z')) do
        expected_hash = {
          id: '1',
          status: 'booked',
          patient_icn: '1234567890V123456',
          created: '2023-10-01T00:00:00Z',
          location_id: 'network_1',
          clinic: 'clinic_1',
          start: '2023-10-10T10:00:00Z',
          contact: 'contact_info',
          referral_id: '12345',
          referral: { referral_number: '12345' },
          provider_service_id: 'clinic_1',
          provider_name: 'unknown',
          kind: 'cc',
          modality: 'communityCareEps',
          type: 'COMMUNITY_CARE_APPOINTMENT',
          pending: false,
          past: true,
          future: false
        }
        expect(subject.serializable_hash).to eq(expected_hash)
      end
    end
  end

  describe 'location functionality' do
    let(:provider_data) do
      OpenStruct.new(
        id: 'provider-123',
        name: 'Test Provider',
        location: OpenStruct.new(
          name: 'Test Medical Center',
          timezone: 'America/New_York'
        )
      )
    end

    let(:appointment_with_provider) { described_class.new(params, provider_data) }

    context 'when provider data is present' do
      it 'includes location data in serializable_hash' do
        result = appointment_with_provider.serializable_hash
        expect(result[:location]).to eq({
                                          id: 'clinic_1',
                                          type: 'appointments',
                                          attributes: {
                                            name: 'Test Medical Center',
                                            timezone: {
                                              timeZoneId: 'America/New_York'
                                            }
                                          }
                                        })
      end

      it 'uses provider_service_id as location id' do
        result = appointment_with_provider.serializable_hash
        expect(result[:location][:id]).to eq('clinic_1')
      end

      it 'sets type as appointments' do
        result = appointment_with_provider.serializable_hash
        expect(result[:location][:type]).to eq('appointments')
      end

      it 'includes provider location name' do
        result = appointment_with_provider.serializable_hash
        expect(result[:location][:attributes][:name]).to eq('Test Medical Center')
      end

      it 'includes timezone from provider location' do
        result = appointment_with_provider.serializable_hash
        expect(result[:location][:attributes][:timezone][:timeZoneId]).to eq('America/New_York')
      end

      it 'defaults to UTC when timezone is blank' do
        provider_data.location.timezone = ''
        appointment = described_class.new(params, provider_data)
        result = appointment.serializable_hash
        expect(result[:location][:attributes][:timezone][:timeZoneId]).to eq('UTC')
      end

      it 'defaults to UTC when timezone is nil' do
        provider_data.location.timezone = nil
        appointment = described_class.new(params, provider_data)
        result = appointment.serializable_hash
        expect(result[:location][:attributes][:timezone][:timeZoneId]).to eq('UTC')
      end
    end

    context 'when provider data is nil' do
      it 'sets location to nil' do
        result = subject.serializable_hash
        expect(result[:location]).to be_nil
      end
    end

    context 'when provider has no location data' do
      let(:provider_without_location) { OpenStruct.new(id: 'provider-123', name: 'Test Provider') }
      let(:appointment_without_location) { described_class.new(params, provider_without_location) }

      it 'sets location to nil' do
        result = appointment_without_location.serializable_hash
        expect(result[:location]).to be_nil
      end
    end

    context 'when provider location is nil' do
      let(:provider_with_nil_location) { OpenStruct.new(id: 'provider-123', name: 'Test Provider', location: nil) }
      let(:appointment_with_nil_location) { described_class.new(params, provider_with_nil_location) }

      it 'sets location to nil' do
        result = appointment_with_nil_location.serializable_hash
        expect(result[:location]).to be_nil
      end
    end
  end

  describe '#determine_status' do
    it 'returns "booked" when status is "booked"' do
      expect(subject.send(:determine_status, 'booked')).to eq('booked')
    end

    it 'returns "proposed" when status is not "booked"' do
      expect(subject.send(:determine_status, 'proposed')).to eq('proposed')
    end
  end
end
