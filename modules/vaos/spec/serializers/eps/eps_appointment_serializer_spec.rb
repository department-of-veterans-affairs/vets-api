# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::EpsAppointmentSerializer do
  subject(:serialized) { described_class.new(eps_appointment).serializable_hash }

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

  let(:eps_appointment) do
    instance_double(
      VAOS::V2::EpsAppointment,
      id: 'qdm61cJ5',
      status: 'booked',
      start: '2024-11-21T18:00:00Z',
      is_latest: true,
      last_retrieved: '2023-10-01T12:00:00Z',
      type_of_care: 'CARDIOLOGY',
      referral_phone_number: '1234567890',
      provider:,
      provider_details: {
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
      }
    )
  end

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
      let(:eps_appointment) do
        instance_double(
          VAOS::V2::EpsAppointment,
          id: 'qdm61cJ5',
          status: 'booked',
          start: '2024-11-21T18:00:00Z',
          is_latest: true,
          last_retrieved: '2023-10-01T12:00:00Z',
          type_of_care: 'CARDIOLOGY',
          referral_phone_number: '1234567890',
          provider: nil,
          provider_details: nil
        )
      end

      it 'returns nil for provider' do
        expect(serialized[:data][:attributes][:provider]).to be_nil
      end
    end

    context 'when type_of_care is nil' do
      let(:eps_appointment) do
        instance_double(
          VAOS::V2::EpsAppointment,
          id: 'qdm61cJ5',
          status: 'booked',
          start: '2024-11-21T18:00:00Z',
          is_latest: true,
          last_retrieved: '2023-10-01T12:00:00Z',
          type_of_care: nil,
          referral_phone_number: nil,
          provider:,
          provider_details: {
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
            network_ids: ['sandbox-network-test']
          }
        )
      end

      it 'has nil for type_of_care' do
        expect(serialized[:data][:attributes][:type_of_care]).to be_nil
      end

      it 'does not include phone_number in provider data' do
        expect(serialized[:data][:attributes][:provider]).not_to have_key(:phone_number)
      end
    end

    context 'when referral_phone_number is nil but provider details include phone' do
      let(:eps_appointment) do
        instance_double(
          VAOS::V2::EpsAppointment,
          id: 'qdm61cJ5',
          status: 'booked',
          start: '2024-11-21T18:00:00Z',
          is_latest: true,
          last_retrieved: '2023-10-01T12:00:00Z',
          type_of_care: 'CARDIOLOGY',
          referral_phone_number: nil,
          provider:,
          provider_details: {
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
            phone_number: '555-123-4567'
          }
        )
      end

      it 'includes provider_details phone_number in provider data' do
        expect(serialized[:data][:attributes][:provider][:phone_number]).to eq('555-123-4567')
      end
    end
  end
end
