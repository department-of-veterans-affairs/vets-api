# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Eps::DraftAppointmentSerializer do

  subject { serialize(draft_appointment, serializer_class: described_class) }

  let(:provider) do
    double(
      id: '1',
      name: 'Dr. Smith',
      isActive: true,
      individualProviders: ['Dr. Jones', 'Dr. Williams'],
      providerOrganization: 'Medical Group',
      location: { address: '123 Medical St' },
      networkIds: ['sandbox-network-5vuTac8v'],
      schedulingNotes: 'Available weekdays',
      appointmentTypes: [
        {
          id: 'ov',
          name: 'Office Visit',
          isSelfSchedulable: true
        }
      ],
      specialties: [
        {
          id: '208800000X',
          name: 'Urology'
        }
      ],
      visitMode: 'in-person',
      features: {
        isDigital: true
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
          distanceInMiles: 123,
          driveTimeInSecondsWithoutTraffic: 19_096,
          driveTimeInSecondsWithTraffic: 19_561,
          latitude: 44.475883,
          longitude: -73.212074
        },
        '456' => {
          distanceInMiles: 456,
          driveTimeInSecondsWithoutTraffic: 25_000,
          driveTimeInSecondsWithTraffic: 27_000,
          latitude: 45.123456,
          longitude: -74.123456
        }
      }
    )
  end

  let(:draft_appointment) do
    double(
      id: 123,
      provider: provider,
      slots: slots,
      drive_time: drive_time
    )
  end

  # All the lets above would be part of the draft_appointment factory
  # let(:draft_appointment) { build_stubbed(:draft_appointment) }

  let(:data) { JSON.parse(subject)['data'] }
  let(:attributes) { data['attributes'] }

  it 'includes :id' do
    expect(data['id']).to eq draft_appointment.id.to_s
  end

  it 'includes :type' do
    expect(data['type']).to eq 'draft_appointment'
  end

  it 'includes :provider' do
    expected_provider = {
      id: '1',
      name: 'Dr. Smith',
      isActive: true,
      individualProviders: [
        'Dr. Jones',
        'Dr. Williams'
      ]
    }.stringify_keys

    expect(attributes['provider']).to include(expected_provider)
  end

  context 'when provider is nil' do
    let(:provider) { nil }

    it 'returns nil for provider' do
      expect(attributes['provider']).to be_nil
    end
  end

  it 'includes :slots' do
    expect(attributes['slots']).to be_an(Array)
    expect(attributes['slots'].size).to eq(2)
  end

  context 'when slots is nil' do
    let(:slots) { nil }

    it 'returns nil for provider' do
      expect(attributes['slots']).to be_nil
    end
  end

  context 'when multiple destinations exist' do
    it 'includes first destination when multiple destinations exist' do
      expected_destination = {
        distanceInMiles: 123,
        driveTimeInSecondsWithoutTraffic: 19_096,
        driveTimeInSecondsWithTraffic: 19_561,
        latitude: 44.475883,
        longitude: -73.212074
      }.stringify_keys

      expect(attributes['drivetime']['destination']).to eq(expected_destination)

      # Verify the second destination is not included
      unexpected_destination = {
        distanceInMiles: 456,
        driveTimeInSecondsWithoutTraffic: 25_000,
        driveTimeInSecondsWithTraffic: 27_000,
        latitude: 45.123456,
        longitude: -74.123456
      }.stringify_keys

      expect(attributes['drivetime']['destination']).not_to include(unexpected_destination)
    end
  end

  context 'when destinations is empty' do
    let(:drive_time) do
      double(
        origin: { latitude: 37.7749, longitude: -122.4194 },
        destinations: {}
      )
    end

    it 'returns nil for destinations' do
      expect(attributes['drivetime']['destination']).to be_nil
    end
  end

  context 'when drive_time is nil' do
    let(:drive_time) { nil }

    it 'returns nil for drivetime' do
      expect(attributes['drivetime']).to be_nil
    end
  end
end
