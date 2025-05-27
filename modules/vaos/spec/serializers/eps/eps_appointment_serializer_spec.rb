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
      phone: nil
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
        address: {
          street1: '123 Main St',
          street2: 'Suite 456',
          city: 'Anytown',
          state: 'CA',
          zip: '12345'
        }
      }
    )
  end

  describe 'serialization' do
    it 'serializes the appointment with correct structure' do
      expect(serialized[:data][:type]).to eq(:epsAppointment)
      expect(serialized[:data][:id]).to eq('qdm61cJ5')
      expect(serialized[:data][:attributes][:id]).to eq('qdm61cJ5')
      expect(serialized[:data][:attributes][:status]).to eq('booked')
      expect(serialized[:data][:attributes][:start]).to eq('2024-11-21T18:00:00Z')
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
        address: {
          street1: '123 Main St',
          street2: 'Suite 456',
          city: 'Anytown',
          state: 'CA',
          zip: '12345'
        }
      )
    end

    it 'includes empty referring facility details' do
      facility_data = serialized[:data][:attributes][:referringFacility]
      expect(facility_data).to eq({})
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
          provider: nil,
          provider_details: nil
        )
      end

      it 'returns nil for provider' do
        expect(serialized[:data][:attributes][:provider]).to be_nil
      end
    end
  end
end
