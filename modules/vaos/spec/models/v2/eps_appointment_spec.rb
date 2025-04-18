# frozen_string_literal: true

# spec/serializers/vaos/v2/eps_appointment_spec.rb
require 'rails_helper'

describe VAOS::V2::EpsAppointment do
  let(:referral_detail) do
    instance_double(
      Ccra::ReferralDetail,
      category_of_care: 'Primary Care',
      phone_number: '555-123-4567'
    )
  end

  let(:provider) do
    instance_double(
      Eps::Provider,
      id: 'provider_123',
      name: 'Dr. Smith',
      is_active: true,
      provider_organization: 'VA Hospital',
      location: { address: '123 Main St' },
      network_ids: ['network_1']
    )
  end

  let(:appointment_data) do
    {
      id: 1,
      appointment_details: {
        status: 'booked',
        last_retrieved: '2023-10-01T00:00:00Z',
        start: '2023-10-10T10:00:00Z',
        is_latest: true
      },
      referral: { referral_number: '12345' },
      patient_id: '1234567890V123456',
      network_id: 'network_1',
      provider_service_id: 'clinic_1',
      contact: 'contact_info',
      provider: { name: 'Dr. Jones' }
    }
  end

  describe '#initialize with just appointment data' do
    subject { described_class.new(appointment_data) }

    it 'initializes with correct attributes' do
      expect(subject.id).to eq('1')
      expect(subject.status).to eq('booked')
      expect(subject.patient_icn).to eq('1234567890V123456')
      expect(subject.created).to eq('2023-10-01T00:00:00Z')
      expect(subject.location_id).to eq('network_1')
      expect(subject.clinic).to eq('clinic_1')
      expect(subject.start).to eq('2023-10-10T10:00:00Z')
      expect(subject.last_retrieved).to eq('2023-10-01T00:00:00Z')
      expect(subject.is_latest).to be(true)
      expect(subject.contact).to eq('contact_info')
      expect(subject.referral_id).to eq('12345')
      expect(subject.referral).to eq({ referral_number: '12345' })
      expect(subject.provider_name).to eq('Dr. Jones')
      expect(subject.type_of_care).to be_nil
      expect(subject.referral_phone_number).to be_nil
    end
  end

  describe '#initialize with all associated data' do
    subject { described_class.new(appointment_data, referral_detail, provider) }

    it 'initializes with associated data attributes' do
      expect(subject.type_of_care).to eq('Primary Care')
      expect(subject.referral_phone_number).to eq('555-123-4567')
      expect(subject.provider).to eq(provider)
    end
  end

  describe '#provider_details' do
    context 'when provider is present' do
      subject { described_class.new(appointment_data, referral_detail, provider) }

      it 'returns a hash with provider details' do
        expected_details = {
          id: 'provider_123',
          name: 'Dr. Smith',
          is_active: true,
          organization: 'VA Hospital',
          location: { address: '123 Main St' },
          network_ids: ['network_1'],
          phone_number: '555-123-4567'
        }
        expect(subject.provider_details).to eq(expected_details)
      end
    end

    context 'when provider is not present' do
      subject { described_class.new(appointment_data, referral_detail, nil) }

      it 'returns nil' do
        expect(subject.provider_details).to be_nil
      end
    end
  end

  describe '#determine_status' do
    subject { described_class.new(appointment_data) }

    it 'returns "booked" when status is "booked"' do
      expect(subject.send(:determine_status, 'booked')).to eq('booked')
    end

    it 'returns "proposed" when status is not "booked"' do
      expect(subject.send(:determine_status, 'proposed')).to eq('proposed')
    end
  end
end
