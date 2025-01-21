# spec/serializers/vaos/v2/eps_appointment_spec.rb
require 'rails_helper'

describe VAOS::V2::EpsAppointment do
  subject { described_class.new(params) }

  let(:params) do
    {
      id: 1,
      appointment_details: { status: true, last_retrieved: '2023-10-01T00:00:00Z', start: '2023-10-10T10:00:00Z' },
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
    it 'returns a hash with the correct attributes' do
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
        referral: { referral_number: '12345' }
      }
      expect(subject.serializable_hash).to eq(expected_hash)
    end
  end

  describe '#determine_status' do
    it 'returns "booked" when status is true' do
      expect(subject.send(:determine_status, true)).to eq('booked')
    end

    it 'returns "proposed" when status is false' do
      expect(subject.send(:determine_status, false)).to eq('proposed')
    end
  end
end