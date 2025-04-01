# frozen_string_literal: true

require 'rails_helper'

describe Eps::DraftAppointmentService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }
  let(:appointments_service) { instance_double(VAOS::V2::AppointmentsService) }
  let(:eps_provider_service) { instance_double(Eps::ProviderService) }
  let(:eps_appointment_service) { instance_double(Eps::AppointmentService) }
  let(:referral_id) { 'ref-123' }
  let(:provider_id) { '9mN718pH' }
  let(:pagination_params) { { page: 1, per_page: 10 } }
  let(:referral_data) do
    {
      provider_id: provider_id,
      appointment_type_id: 'ov',
      start_date: '2025-01-01T00:00:00Z',
      end_date: '2025-01-03T00:00:00Z'
    }
  end

  before do
    # Set up service mock instances
    allow(VAOS::V2::AppointmentsService).to receive(:new).with(user).and_return(appointments_service)
    allow(Eps::ProviderService).to receive(:new).with(user).and_return(eps_provider_service)
    allow(Eps::AppointmentService).to receive(:new).with(user).and_return(eps_appointment_service)

    # Mock basic behaviors
    redis_client = instance_double(Eps::RedisClient)
    allow(Eps::RedisClient).to receive(:new).and_return(redis_client)
    allow(redis_client).to receive(:fetch_referral_attributes).and_return(referral_data)
    allow(appointments_service).to receive(:referral_appointment_already_exists?).and_return(exists: false, error: false)
  end

  describe '#call' do
    let(:draft_appointment) { OpenStruct.new(id: 'draft-123') }
    let(:provider) do
      OpenStruct.new(
        id: provider_id,
        name: 'Test Provider',
        is_active: true,
        individual_providers: [],
        provider_organization: {},
        location: { latitude: 40.7128, longitude: -74.006 },
        network_ids: [],
        scheduling_notes: '',
        appointment_types: [],
        specialties: [],
        visit_mode: '',
        features: {}
      )
    end
    let(:slots_data) { [{ id: 'slot-1', start: '2025-01-01T10:00:00Z' }] }
    let(:slots) { OpenStruct.new(slots: slots_data) }
    let(:drive_time) do
      OpenStruct.new(
        origin: { latitude: 40.7128, longitude: -74.006 },
        destinations: { provider_id => { distanceInMiles: 10 } }
      )
    end

    before do
      # Mock successful service calls
      allow(eps_appointment_service).to receive(:create_draft_appointment).and_return(draft_appointment)
      allow(eps_provider_service).to receive(:get_provider_service).and_return(provider)
      allow(eps_provider_service).to receive(:get_provider_slots).and_return(slots)
      allow(eps_provider_service).to receive(:get_drive_times).and_return(drive_time)
      allow(user).to receive(:vet360_contact_info).and_return(
        OpenStruct.new(residential_address: OpenStruct.new(latitude: 40.7128, longitude: -74.006))
      )
    end

    it 'returns a successful response with all data' do
      result = subject.call(referral_id, pagination_params)

      expect(result[:status]).to eq(:created)

      serialized_data = result[:json].serializable_hash
      expect(serialized_data).to have_key(:data)
      expect(serialized_data[:data]).to have_key(:attributes)

      attributes = serialized_data[:data][:attributes]
      expect(attributes).to have_key(:provider)
      expect(attributes).to have_key(:slots)
      expect(attributes).to have_key(:drivetime)

      expect(attributes[:provider][:id]).to eq(provider_id)

      # Verify slots are correctly serialized
      expect(attributes[:slots]).to eq(slots_data)

      # Verify drive time is correctly serialized
      expect(attributes[:drivetime][:destination]).to eq(drive_time.destinations[provider_id])
    end

    context 'when Redis connection fails' do
      before do
        redis_client = instance_double(Eps::RedisClient)
        allow(Eps::RedisClient).to receive(:new).and_return(redis_client)
        allow(redis_client).to receive(:fetch_referral_attributes).and_raise(Redis::BaseError, 'Redis connection error')
      end

      it 'raises a ServiceError with appropriate details' do
        result = subject.call(referral_id, pagination_params)

        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:json][:errors].first[:title]).to eq('Failed to retrieve referral data from cache')
        expect(result[:json][:errors].first[:detail]).to eq('Redis connection error')
        expect(result[:json][:errors].first[:code]).to eq('Eps::DraftAppointmentService::ServiceError')
      end
    end

    context 'when referral data is invalid' do
      let(:referral_data) { nil }

      it 'raises a ServiceError with appropriate details' do
        result = subject.call(referral_id, pagination_params)

        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:json][:errors].first[:title]).to eq('Invalid referral data')
        expect(result[:json][:errors].first[:detail]).to eq('Required referral data is missing or incomplete: all required attributes')
        expect(result[:json][:errors].first[:code]).to eq('Eps::DraftAppointmentService::ServiceError')
      end
    end

    context 'when checking for referral usage fails' do
      before do
        allow(appointments_service).to receive(:referral_appointment_already_exists?).and_return(
          exists: false, error: true, failures: 'Failed to check referral usage'
        )
      end

      it 'raises a ServiceError with appropriate details' do
        result = subject.call(referral_id, pagination_params)

        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:json][:errors].first[:title]).to eq('Upstream error checking if referral is already in use')
        expect(result[:json][:errors].first[:detail]).to eq('Failed to check referral usage')
        expect(result[:json][:errors].first[:code]).to eq('Eps::DraftAppointmentService::ServiceError')
      end
    end

    context 'when referral is already used' do
      before do
        allow(appointments_service).to receive(:referral_appointment_already_exists?).and_return(
          exists: true, error: false
        )
      end

      it 'raises a ServiceError with appropriate details' do
        result = subject.call(referral_id, pagination_params)

        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:json][:errors].first[:title]).to eq('Referral is already used for an existing appointment')
        expect(result[:json][:errors].first[:detail]).to eq("Referral #{referral_id} is already associated with an existing appointment")
        expect(result[:json][:errors].first[:code]).to eq('Eps::DraftAppointmentService::ServiceError')
      end
    end

    context 'with unexpected errors' do
      before do
        allow(eps_appointment_service).to receive(:create_draft_appointment).and_raise(
          StandardError, 'Unexpected service error'
        )
      end

      it 'wraps the error in a ServiceError response' do
        result = subject.call(referral_id, pagination_params)

        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:json][:errors].first[:title]).to eq('Unexpected error occurred in draft appointment service')
        expect(result[:json][:errors].first[:detail]).to eq('Unexpected service error')
        expect(result[:json][:errors].first[:code]).to eq('Eps::DraftAppointmentService::ServiceError')
      end
    end
  end
end