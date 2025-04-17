# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::EpsAppointmentSerializer do
  let(:provider) do
    double(
      id: 'test-provider-id',
      name: 'Timothy Bob',
      is_active: true,
      provider_organization: {
        name: 'test-provider-org-name'
      },
      location: {
        name: 'Test Medical Complex',
        address: '207 Davishill Ln',
        latitude: 33.058736,
        longitude: -80.032819,
        timezone: 'America/New_York'
      },
      network_ids: ['sandbox-network-test'],
      phone_number: nil
    )
  end

  let(:referral_detail) do
    double(
      category_of_care: 'CARDIOLOGY',
      phone_number: '1234567890'
    )
  end

  let(:appointment) do
    {
      id: 'qdm61cJ5',
      status: 'booked',
      start: '2024-11-21T18:00:00Z',
      appointmentDetails: {
        status: 'booked',
        start: '2024-11-21T18:00:00Z',
        isLatest: true,
        lastRetrieved: '2023-10-01T12:00:00Z'
      }
    }
  end

  let(:eps_appointment) do
    double(
      id: 'qdm61cJ5',
      appointment: appointment,
      provider: provider,
      referral_detail: referral_detail
    )
  end

  subject(:serialized) { described_class.new(eps_appointment).serializable_hash }

  describe 'serialization' do
    it 'serializes the appointment with correct structure' do
      expect(serialized[:data][:type]).to eq(:eps_appointment)
      expect(serialized[:data][:id]).to eq('qdm61cJ5')
      expect(serialized[:data][:attributes][:id]).to eq('qdm61cJ5')
      expect(serialized[:data][:attributes][:status]).to eq('booked')
      expect(serialized[:data][:attributes][:start]).to eq('2024-11-21T18:00:00Z')
      expect(serialized[:data][:attributes][:type_of_care]).to eq('CARDIOLOGY')
      expect(serialized[:data][:attributes][:modality]).to eq('OV')
    end

    it 'includes provider details' do
      provider_data = serialized[:data][:attributes][:provider]
      expect(provider_data).to include(
        id: 'test-provider-id',
        name: 'Timothy Bob',
        is_active: true,
        organization: {
          name: 'test-provider-org-name'
        },
        location: {
          name: 'Test Medical Complex',
          address: '207 Davishill Ln',
          latitude: 33.058736,
          longitude: -80.032819,
          timezone: 'America/New_York'
        },
        network_ids: ['sandbox-network-test'],
        phone_number: '1234567890'
      )
    end
  end

  describe 'edge cases' do
    context 'when provider is nil' do
      let(:provider) { nil }

      it 'returns nil for provider' do
        expect(serialized[:data][:attributes][:provider]).to be_nil
      end
    end

    context 'when referral_detail is nil' do
      let(:referral_detail) { nil }

      it 'has nil for type_of_care' do
        expect(serialized[:data][:attributes][:type_of_care]).to be_nil
      end

      it 'does not include phone_number from referral in provider data' do
        expect(serialized[:data][:attributes][:provider]).not_to have_key(:phone_number)
      end
    end

    context 'when provider has phone_number but referral_detail is nil' do
      let(:provider) do
        double(
          id: 'test-provider-id',
          name: 'Timothy Bob',
          is_active: true,
          provider_organization: {
            name: 'test-provider-org-name'
          },
          location: {
            name: 'Test Medical Complex',
            address: '207 Davishill Ln',
            latitude: 33.058736,
            longitude: -80.032819,
            timezone: 'America/New_York'
          },
          network_ids: ['sandbox-network-test'],
          phone_number: '555-123-4567'
        )
      end

      let(:referral_detail) { nil }

      it 'does not include phone_number in provider data' do
        expect(serialized[:data][:attributes][:provider]).not_to have_key(:phone_number)
      end
    end

    context 'when provider and referral_detail have phone numbers' do
      let(:provider) do
        double(
          id: 'test-provider-id',
          name: 'Timothy Bob',
          is_active: true,
          provider_organization: {
            name: 'test-provider-org-name'
          },
          location: {
            name: 'Test Medical Complex',
            address: '207 Davishill Ln',
            latitude: 33.058736,
            longitude: -80.032819,
            timezone: 'America/New_York'
          },
          network_ids: ['sandbox-network-test'],
          phone_number: '555-123-4567'
        )
      end

      let(:referral_detail) do
        double(
          category_of_care: 'CARDIOLOGY',
          phone_number: '1234567890'
        )
      end

      it 'uses phone_number from referral_detail' do
        expect(serialized[:data][:attributes][:provider][:phone_number]).to eq('1234567890')
      end
    end

    context 'when no phone numbers are available' do
      let(:provider) do
        double(
          id: 'test-provider-id',
          name: 'Timothy Bob',
          is_active: true,
          provider_organization: {
            name: 'test-provider-org-name'
          },
          location: {
            name: 'Test Medical Complex',
            address: '207 Davishill Ln',
            latitude: 33.058736,
            longitude: -80.032819,
            timezone: 'America/New_York'
          },
          network_ids: ['sandbox-network-test'],
          phone_number: nil
        )
      end

      let(:referral_detail) do
        double(
          category_of_care: 'CARDIOLOGY',
          phone_number: nil
        )
      end

      it 'does not include phone_number in provider data' do
        expect(serialized[:data][:attributes][:provider]).not_to have_key(:phone_number)
      end
    end
  end
end
