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
      },
      modality: 'communityCareEps',
      past: true,
      referral_id: 'REF-12345',
      location: {
        id: 'Aq7wgAux',
        type: 'appointments',
        attributes: {
          name: 'Test Medical Complex',
          timezone: {
            timeZoneId: 'America/New_York'
          }
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
      expect(serialized[:data][:attributes][:modality]).to eq('communityCareEps')
      expect(serialized[:data][:attributes][:location]).to eq({
                                                                id: 'Aq7wgAux',
                                                                type: 'appointments',
                                                                attributes: {
                                                                  name: 'Test Medical Complex',
                                                                  timezone: {
                                                                    timeZoneId: 'America/New_York'
                                                                  }
                                                                }
                                                              })
      expect(serialized[:data][:attributes][:past]).to be(true)
      expect(serialized[:data][:attributes][:referralId]).to eq('REF-12345')
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
  end

  describe 'location functionality' do
    it 'includes location data when present' do
      expect(serialized[:data][:attributes][:location]).to eq({
                                                                id: 'Aq7wgAux',
                                                                type: 'appointments',
                                                                attributes: {
                                                                  name: 'Test Medical Complex',
                                                                  timezone: {
                                                                    timeZoneId: 'America/New_York'
                                                                  }
                                                                }
                                                              })
    end

    context 'when location data is nil' do
      let(:eps_appointment) do
        instance_double(
          VAOS::V2::EpsAppointment,
          id: 'qdm61cJ5',
          status: 'booked',
          start: '2024-11-21T18:00:00Z',
          is_latest: true,
          last_retrieved: '2023-10-01T12:00:00Z',
          provider: nil,
          provider_details: nil,
          modality: 'communityCareEps',
          past: true,
          referral_id: nil,
          location: nil
        )
      end

      it 'returns nil for location' do
        expect(serialized[:data][:attributes][:location]).to be_nil
      end
    end

    context 'when location data is empty' do
      let(:eps_appointment) do
        instance_double(
          VAOS::V2::EpsAppointment,
          id: 'qdm61cJ5',
          status: 'booked',
          start: '2024-11-21T18:00:00Z',
          is_latest: true,
          last_retrieved: '2023-10-01T12:00:00Z',
          provider: nil,
          provider_details: nil,
          modality: 'communityCareEps',
          past: true,
          referral_id: nil,
          location: {}
        )
      end

      it 'returns nil for location when empty' do
        expect(serialized[:data][:attributes][:location]).to be_nil
      end
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
          provider_details: nil,
          modality: 'communityCareEps',
          past: true,
          referral_id: 'REF-12345',
          location: nil
        )
      end

      it 'returns nil for provider' do
        expect(serialized[:data][:attributes][:provider]).to be_nil
      end
    end
  end

  describe 'referral_id functionality' do
    it 'includes referralId when present' do
      expect(serialized[:data][:attributes][:referralId]).to eq('REF-12345')
    end

    context 'when referral_id is nil' do
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
          },
          modality: 'communityCareEps',
          past: true,
          referral_id: nil,
          location: {
            id: 'Aq7wgAux',
            type: 'appointments',
            attributes: {
              name: 'Test Medical Complex',
              timezone: {
                timeZoneId: 'America/New_York'
              }
            }
          }
        )
      end

      it 'returns nil for referralId' do
        expect(serialized[:data][:attributes][:referralId]).to be_nil
      end
    end
  end
end
