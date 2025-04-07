# frozen_string_literal: true

require 'rails_helper'

describe Eps::DraftAppointmentService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos, icn: 'care-nav-patient-casey') }
  let(:appointments_service) { instance_double(VAOS::V2::AppointmentsService) }
  let(:eps_provider_service) { instance_double(Eps::ProviderService) }
  let(:eps_appointment_service) { instance_double(Eps::AppointmentService) }
  let(:eps_redis_client) { instance_double(Eps::RedisClient) }
  let(:referral_id) { 'ref-123' }
  let(:provider_id) { '9mN718pH' }
  let(:pagination_params) { { page: 1, per_page: 10 } }
  let(:referral_data) do
    {
      provider_id:,
      appointment_type_id: 'ov',
      start_date: '2025-01-01T00:00:00Z',
      end_date: '2025-01-03T00:00:00Z'
    }
  end

  # Mock data for successful responses
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

  # Setup for each test group
  before do
    # Setup external service dependencies
    allow(VAOS::V2::AppointmentsService).to receive(:new).with(user).and_return(appointments_service)
    allow(Eps::ProviderService).to receive(:new).with(user).and_return(eps_provider_service)
    allow(Eps::AppointmentService).to receive(:new).with(user).and_return(eps_appointment_service)
    allow(Eps::RedisClient).to receive(:new).and_return(eps_redis_client)
  end

  # Helper methods for testing
  def expect_draft_appointment_error(status)
    expect { subject.create_draft_appointment(referral_id, pagination_params) }
      .to raise_error(Eps::DraftAppointmentServiceError)

    begin
      subject.create_draft_appointment(referral_id, pagination_params)
    rescue Eps::DraftAppointmentServiceError => e
      expect(e.status).to eq(status)
    end
  end

  # Shared contexts for common setups
  shared_context 'with successful dependencies' do
    before do
      allow(eps_redis_client).to receive(:fetch_referral_attributes)
        .with(referral_number: referral_id)
        .and_return(referral_data)

      allow(appointments_service).to receive(:referral_appointment_already_exists?)
        .with(referral_id, pagination_params)
        .and_return(exists: false, error: false)

      allow(eps_provider_service).to receive(:get_provider_service)
        .with(provider_id:)
        .and_return(provider)

      allow(eps_provider_service).to receive_messages(
        get_provider_slots: slots,
        get_drive_times: drive_time
      )

      allow(eps_appointment_service).to receive(:create_draft_appointment)
        .with(referral_id:)
        .and_return(draft_appointment)

      # User address setup
      allow(user).to receive(:vet360_contact_info).and_return(
        OpenStruct.new(residential_address: OpenStruct.new(latitude: 40.7128, longitude: -74.006))
      )
    end
  end

  # Shared examples for error cases
  shared_examples 'a service error with status' do |status|
    it "raises a DraftAppointmentServiceError with #{status} status" do
      expect_draft_appointment_error(status)
    end
  end

  shared_examples 'returns data without drive time' do
    it 'returns data without drive time information' do
      result = subject.create_draft_appointment(referral_id, pagination_params)

      expect(result).to be_a(OpenStruct)
      expect(result.drive_time).to be_nil
    end
  end

  describe '#create_draft_appointment' do
    context 'when all services respond successfully' do
      include_context 'with successful dependencies'

      it 'returns an OpenStruct with the collected data' do
        result = subject.create_draft_appointment(referral_id, pagination_params)

        expect(result).to be_a(OpenStruct)
        expect(result.id).to eq('draft-123')
        expect(result.provider).to eq(provider)
        expect(result.slots).to eq(slots)
        expect(result.drive_time).to eq(drive_time)
      end
    end

    context 'when referral ID is blank' do
      it 'raises an error with empty referral ID' do
        expect { subject.create_draft_appointment('', pagination_params) }
          .to raise_error(Eps::DraftAppointmentServiceError)

        begin
          subject.create_draft_appointment('', pagination_params)
        rescue Eps::DraftAppointmentServiceError => e
          expect(e.status).to eq(:bad_gateway)
        end
      end

      it 'raises an error with nil referral ID' do
        expect { subject.create_draft_appointment(nil, pagination_params) }
          .to raise_error(Eps::DraftAppointmentServiceError)

        begin
          subject.create_draft_appointment(nil, pagination_params)
        rescue Eps::DraftAppointmentServiceError => e
          expect(e.status).to eq(:bad_gateway)
        end
      end
    end

    context 'when Redis connection fails' do
      before do
        redis_error = Redis::BaseError.new('Redis connection error')
        allow(eps_redis_client).to receive(:fetch_referral_attributes)
          .with(referral_number: referral_id)
          .and_raise(redis_error)
      end

      it_behaves_like 'a service error with status', :bad_gateway
    end

    context 'when referral data is invalid' do
      before do
        allow(eps_redis_client).to receive(:fetch_referral_attributes)
          .with(referral_number: referral_id)
          .and_return(nil)
      end

      it_behaves_like 'a service error with status', :unprocessable_entity
    end

    context 'when referral data has missing fields' do
      before do
        allow(eps_redis_client).to receive(:fetch_referral_attributes)
          .with(referral_number: referral_id)
          .and_return({ provider_id: 'some-id' })
      end

      it_behaves_like 'a service error with status', :unprocessable_entity
    end

    context 'when checking for referral usage fails' do
      before do
        allow(eps_redis_client).to receive(:fetch_referral_attributes)
          .with(referral_number: referral_id)
          .and_return(referral_data)

        allow(appointments_service).to receive(:referral_appointment_already_exists?)
          .with(referral_id, pagination_params)
          .and_return(
            exists: false,
            error: true,
            failures: 'Failed to check referral usage'
          )
      end

      it_behaves_like 'a service error with status', :bad_gateway
    end

    context 'when referral is already used' do
      before do
        allow(eps_redis_client).to receive(:fetch_referral_attributes)
          .with(referral_number: referral_id)
          .and_return(referral_data)

        allow(appointments_service).to receive(:referral_appointment_already_exists?)
          .with(referral_id, pagination_params)
          .and_return(exists: true, error: false)
      end

      it_behaves_like 'a service error with status', :unprocessable_entity
    end

    context 'with service failures' do
      # Test various service failures
      {
        'provider service' => {
          service: :get_provider_service,
          args: { provider_id: '9mN718pH' },
          error_class: Common::Exceptions::BackendServiceException,
          error_args: ['VA900', { detail: 'Provider not found' }, 404, 'Provider not found'],
          expected_status: :bad_gateway
        },
        'slots service' => {
          service: :get_provider_slots,
          args: nil,
          error_class: Common::Exceptions::BackendServiceException,
          error_args: ['VA900', { detail: 'No available slots' }, 404, 'No available slots'],
          expected_status: :bad_gateway
        },
        'drive time service' => {
          service: :get_drive_times,
          args: nil,
          error_class: Common::Exceptions::BackendServiceException,
          error_args: ['VA900', { detail: 'Drive time calculation failed' }, 500, 'Drive time calculation failed'],
          expected_status: :bad_gateway
        },
        'draft appointment creation' => {
          service: :create_draft_appointment,
          service_class: :eps_appointment_service,
          args: { referral_id: 'ref-123' },
          error_class: Common::Exceptions::BackendServiceException,
          error_args: ['VA900', { detail: 'Failed to create draft appointment' }, 500,
                       'Failed to create draft appointment'],
          expected_status: :bad_gateway
        }
      }.each do |service_name, config|
        context "when #{service_name} fails" do
          include_context 'with successful dependencies'

          before do
            service_class = config[:service_class] || :eps_provider_service
            error = config[:error_class].new(*config[:error_args])

            if config[:args].nil?
              allow(send(service_class)).to receive(config[:service]).and_raise(error)
            else
              allow(send(service_class)).to receive(config[:service]).with(config[:args]).and_raise(error)
            end
          end

          it_behaves_like 'a service error with status', :bad_gateway
        end
      end
    end

    context 'when user address is incomplete' do
      include_context 'with successful dependencies'

      before do
        allow(user).to receive(:vet360_contact_info).and_return(
          OpenStruct.new(residential_address: OpenStruct.new(latitude: nil, longitude: nil))
        )
      end

      it_behaves_like 'returns data without drive time'
    end

    context 'when user has no address' do
      include_context 'with successful dependencies'

      before do
        allow(user).to receive(:vet360_contact_info).and_return(nil)
      end

      it_behaves_like 'returns data without drive time'
    end
  end
end
