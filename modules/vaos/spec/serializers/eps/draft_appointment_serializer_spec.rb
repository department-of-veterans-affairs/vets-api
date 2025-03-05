# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::DraftAppointmentSerializer do
  let(:provider) do
    double(
      id: '1',
      name: 'Dr. Smith',
      is_active: true,
      individual_providers: ['Dr. Jones', 'Dr. Williams'],
      provider_organization: 'Medical Group',
      location: { address: '123 Medical St' },
      network_ids: ['sandbox-network-5vuTac8v'],
      scheduling_notes: 'Available weekdays',
      appointment_types: [
        {
          id: 'ov',
          name: 'Office Visit',
          is_self_schedulable: true
        }
      ],
      specialties: [
        {
          id: '208800000X',
          name: 'Urology'
        }
      ],
      visit_mode: 'in-person',
      features: {
        is_digital: true
      }
    )
  end

  let(:slots) do
    double(
      count: 2,
      slots: [
        { id: '123', start: '2025-01-16T09:00:00Z' },
        { id: '456', start: '2025-01-16T09:00:00Z' }
      ]
    )
  end

  let(:drive_time) do
    double(
      origin: { latitude: 37.7749, longitude: -122.4194 },
      destinations: {
        '123' => {
          distance_in_miles: 123,
          drive_time_in_seconds_without_traffic: 19_096,
          drive_time_in_seconds_with_traffic: 19_561,
          latitude: 44.475883,
          longitude: -73.212074
        },
        '456' => {
          distance_in_miles: 456,
          drive_time_in_seconds_without_traffic: 25_000,
          drive_time_in_seconds_with_traffic: 27_000,
          latitude: 45.123456,
          longitude: -74.123456
        }
      }
    )
  end

  let(:draft_appointment) do
    double(
      id: 123,
      provider:,
      slots:,
      drive_time:
    )
  end

  describe '#serializable_hash' do
    subject(:serialized_json) { described_class.new(draft_appointment).serializable_hash }

    it 'has the correct structure' do
      expect(serialized_json).to include(
        data: {
          id: '123',
          type: :draft_appointment,
          attributes: {
            provider: {
              id: '1',
              name: 'Dr. Smith',
              is_active: true,
              individual_providers: ['Dr. Jones', 'Dr. Williams'],
              provider_organization: 'Medical Group',
              location: { address: '123 Medical St' },
              network_ids: ['sandbox-network-5vuTac8v'],
              scheduling_notes: 'Available weekdays',
              appointment_types: [
                {
                  id: 'ov',
                  name: 'Office Visit',
                  is_self_schedulable: true
                }
              ],
              specialties: [
                {
                  id: '208800000X',
                  name: 'Urology'
                }
              ],
              visit_mode: 'in-person',
              features: {
                is_digital: true
              }
            },
            slots: [
              { id: '123', start: '2025-01-16T09:00:00Z' },
              { id: '456', start: '2025-01-16T09:00:00Z' }
            ],
            drivetime: {
              origin: { latitude: 37.7749, longitude: -122.4194 },
              destination: {
                distance_in_miles: 123,
                drive_time_in_seconds_without_traffic: 19_096,
                drive_time_in_seconds_with_traffic: 19_561,
                latitude: 44.475883,
                longitude: -73.212074
              }
            }
          }
        }
      )
    end

    describe 'provider' do
      context 'when provider is nil' do
        let(:provider) { nil }

        it 'returns nil for provider' do
          provider_data = serialized_json.dig(:data, :attributes, :provider)
          expect(provider_data).to be_nil
        end
      end

      it 'includes provider details' do
        provider_data = serialized_json.dig(:data, :attributes, :provider)
        expect(provider_data).to include(
          id: '1',
          name: 'Dr. Smith',
          is_active: true,
          individual_providers: [
            'Dr. Jones',
            'Dr. Williams'
          ]
        )
      end
    end

    describe 'slots' do
      context 'when slots is nil' do
        let(:slots) { nil }

        it 'returns nil for slots' do
          slots_data = serialized_json.dig(:data, :attributes, :slots)
          expect(slots_data).to be_nil
        end
      end

      it 'includes slots array' do
        slots_data = serialized_json.dig(:data, :attributes, :slots)
        expect(slots_data).to be_an(Array)
        expect(slots_data.length).to eq(2)
      end
    end

    describe 'drivetime' do
      it 'includes first destination when multiple destinations exist' do
        drivetime_data = serialized_json.dig(:data, :attributes, :drivetime)
        expect(drivetime_data[:destination]).to eq(
          distance_in_miles: 123,
          drive_time_in_seconds_without_traffic: 19_096,
          drive_time_in_seconds_with_traffic: 19_561,
          latitude: 44.475883,
          longitude: -73.212074
        )
        # Verify the second destination is not included
        expect(drivetime_data[:destination]).not_to include(
          distanceInMiles: 456,
          drive_time_in_seconds_without_traffic: 25_000,
          drive_time_in_seconds_with_traffic: 27_000,
          latitude: 45.123456,
          longitude: -74.123456
        )
      end

      context 'when destinations is empty' do
        let(:drive_time) do
          double(
            origin: { latitude: 37.7749, longitude: -122.4194 },
            destinations: {}
          )
        end

        it 'returns nil for destinations' do
          drivetime_data = serialized_json.dig(:data, :attributes, :drivetime)
          expect(drivetime_data[:destination]).to be_nil
        end
      end

      context 'when drive_time is nil' do
        let(:drive_time) { nil }

        it 'returns nil for drivetime' do
          drivetime_data = serialized_json.dig(:data, :attributes, :drivetime)
          expect(drivetime_data).to be_nil
        end
      end
    end
  end
end
