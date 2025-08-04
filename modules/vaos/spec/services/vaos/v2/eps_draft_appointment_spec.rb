# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::EpsDraftAppointment, type: :service do
  include ActiveSupport::Testing::TimeHelpers
  subject { described_class.new(current_user, referral_id, referral_consult_id) }

  let(:current_user) { build(:user, :vaos) }

  let(:referral_id) { 'test-referral-123' }
  let(:referral_consult_id) { 'consult-456' }
  let(:ccra_referral_service) { instance_double(Ccra::ReferralService) }
  let(:eps_appointment_service) { instance_double(Eps::AppointmentService) }
  let(:eps_provider_service) { instance_double(Eps::ProviderService) }
  let(:appointments_service) { instance_double(VAOS::V2::AppointmentsService) }
  let(:referral_data) do
    OpenStruct.new(
      provider_npi: '1234567890',
      referral_date: '2024-01-15',
      expiration_date: '2024-04-15',
      provider_specialty: 'Cardiology',
      treating_facility_address: { city: 'Denver', state: 'CO' },
      referring_facility_code: 'FAC123'
    )
  end
  let(:provider_data) do
    OpenStruct.new(
      id: 'provider-123',
      network_ids: %w[network-1 network-2],
      appointment_types: [
        { id: 'type-1', is_self_schedulable: true },
        { id: 'type-2', is_self_schedulable: false }
      ],
      location: { latitude: 39.7392, longitude: -104.9903 }
    )
  end
  let(:draft_appointment) { OpenStruct.new(id: 'draft-123') }
  let(:slots_data) { [{ start: '2024-01-20T10:00:00Z', end: '2024-01-20T11:00:00Z' }] }
  let(:drive_time_data) { { duration: 1800, distance: 15 } }

  before do
    allow(Ccra::ReferralService).to receive(:new).and_return(ccra_referral_service)
    allow(Eps::AppointmentService).to receive(:new).and_return(eps_appointment_service)
    allow(Eps::ProviderService).to receive(:new).and_return(eps_provider_service)
    allow(VAOS::V2::AppointmentsService).to receive(:new).and_return(appointments_service)
    setup_successful_services
  end

  # Shared examples for error scenarios
  shared_examples 'returns error response' do |expected_message_match, expected_status|
    it "returns error response with #{expected_message_match}" do
      expect(subject.error).to be_present
      expect(subject.error[:message]).to match(expected_message_match)
      expect(subject.error[:status]).to eq(expected_status)
    end
  end

  # Shared setup for successful scenarios
  def setup_successful_services
    allow(ccra_referral_service).to receive(:get_referral).and_return(referral_data)
    allow(appointments_service).to receive(:referral_appointment_already_exists?)
      .and_return({ error: false, exists: false })
    allow(eps_appointment_service).to receive_messages(create_draft_appointment: draft_appointment,
                                                       config: OpenStruct.new(mock_enabled?: false))
    allow(eps_provider_service).to receive_messages(search_provider_services: provider_data,
                                                    get_provider_slots: slots_data, get_drive_times: drive_time_data)
    allow(current_user).to receive(:vet360_contact_info).and_return(
      OpenStruct.new(residential_address: OpenStruct.new(latitude: 39.7392, longitude: -104.9903))
    )
  end

  describe '#initialize' do
    context 'parameter validation' do
      context 'when current_user is nil' do
        let(:current_user) { nil }

        include_examples 'returns error response', 'User authentication required', :unauthorized
      end

      context 'when referral_id is blank' do
        let(:referral_id) { '' }

        include_examples 'returns error response', /Missing required parameters: referral_id/, :bad_request
      end

      context 'when referral_consult_id is nil' do
        let(:referral_consult_id) { nil }

        include_examples 'returns error response', /Missing required parameters: referral_consult_id/, :bad_request
      end

      context 'when current_user.icn is blank' do
        before do
          allow(current_user).to receive(:icn).and_return('')
        end

        include_examples 'returns error response', /Missing required parameters: user ICN/, :bad_request
      end

      context 'when multiple parameters are missing' do
        let(:referral_id) { '' }
        let(:referral_consult_id) { nil }

        before do
          allow(current_user).to receive(:icn).and_return('')
        end

        it 'reports all missing parameters' do
          expect(subject.error).to be_present
          expect(subject.error[:message]).to eq(
            'Missing required parameters: referral_id, referral_consult_id, user ICN'
          )
          expect(subject.error[:status]).to eq(:bad_request)
        end
      end
    end

    context 'when all services return successfully' do
      it 'returns a successful response with all data' do
        expect(subject.error).to be_nil
        expect(subject.id).to eq('draft-123')
        expect(subject.provider).to eq(provider_data)
        expect(subject.slots).to eq(slots_data)
        expect(subject.drive_time).to eq(drive_time_data)
      end

      it 'calls all services with correct parameters' do
        subject

        expect(ccra_referral_service).to have_received(:get_referral)
          .with(referral_consult_id, current_user.icn)
        expect(appointments_service).to have_received(:referral_appointment_already_exists?)
          .with(referral_id)
        expect(eps_provider_service).to have_received(:search_provider_services)
          .with(npi: '1234567890', specialty: 'Cardiology', address: { city: 'Denver', state: 'CO' })
        expect(eps_appointment_service).to have_received(:create_draft_appointment)
          .with(referral_id:)
      end

      context 'when EPS mocks are enabled' do
        before do
          allow(eps_appointment_service).to receive(:config).and_return(OpenStruct.new(mock_enabled?: true))
        end

        it 'skips drive time calculation' do
          expect(subject.drive_time).to be_nil
          expect(eps_provider_service).not_to have_received(:get_drive_times)
        end
      end

      context 'when user has no residential address' do
        before do
          allow(current_user).to receive(:vet360_contact_info).and_return(nil)
        end

        it 'returns nil for drive time' do
          expect(subject.drive_time).to be_nil
          expect(eps_provider_service).not_to have_received(:get_drive_times)
        end
      end
    end

    context 'referral data validation errors' do
      context 'when referral data is invalid' do
        before do
          invalid_referral = OpenStruct.new(provider_npi: nil, referral_date: nil, expiration_date: nil)
          allow(ccra_referral_service).to receive(:get_referral).and_return(invalid_referral)
        end

        include_examples 'returns error response', /Required referral data is missing/, :unprocessable_entity
      end

      context 'when referral data is nil' do
        before do
          allow(ccra_referral_service).to receive(:get_referral).and_return(nil)
        end

        include_examples 'returns error response', /all required attributes/, :unprocessable_entity
      end

      context 'when referral date format is invalid' do
        before do
          invalid_date_referral = referral_data.dup
          invalid_date_referral.referral_date = 'invalid-date-format'
          allow(ccra_referral_service).to receive(:get_referral).and_return(invalid_date_referral)
        end

        include_examples 'returns error response', /invalid date format/, :unprocessable_entity
      end

      context 'when expiration date format is invalid' do
        before do
          invalid_date_referral = referral_data.dup
          invalid_date_referral.expiration_date = 'another-invalid-date'
          allow(ccra_referral_service).to receive(:get_referral).and_return(invalid_date_referral)
        end

        include_examples 'returns error response', /invalid date format/, :unprocessable_entity
      end

      context 'when Redis connection fails' do
        before do
          allow(ccra_referral_service).to receive(:get_referral).and_raise(Redis::BaseError, 'Connection refused')
        end

        include_examples 'returns error response', 'Redis connection error', :bad_gateway
      end
    end

    context 'referral usage validation errors' do
      before do
        allow(ccra_referral_service).to receive(:get_referral).and_return(referral_data)
      end

      context 'when appointment check fails' do
        before do
          allow(appointments_service).to receive(:referral_appointment_already_exists?)
            .and_return({ error: true, failures: 'Service unavailable' })
        end

        include_examples 'returns error response', /Error checking existing appointments/, :bad_gateway
      end

      context 'when referral is already used' do
        before do
          allow(appointments_service).to receive(:referral_appointment_already_exists?)
            .and_return({ error: false, exists: true })
        end

        include_examples 'returns error response', 'No new appointment created: referral is already used',
                         :unprocessable_entity
      end
    end

    context 'provider validation errors' do
      before do
        allow(ccra_referral_service).to receive(:get_referral).and_return(referral_data)
        allow(appointments_service).to receive(:referral_appointment_already_exists?)
          .and_return({ error: false, exists: false })
      end

      context 'when provider is not found or has no ID' do
        before do
          allow(eps_provider_service).to receive(:search_provider_services).and_return(nil)
        end

        include_examples 'returns error response', 'Provider not found', :not_found
      end
    end

    context 'draft appointment creation errors' do
      before do
        allow(ccra_referral_service).to receive(:get_referral).and_return(referral_data)
        allow(appointments_service).to receive(:referral_appointment_already_exists?)
          .and_return({ error: false, exists: false })
        allow(eps_provider_service).to receive(:search_provider_services).and_return(provider_data)
      end

      context 'when draft appointment creation fails' do
        before do
          allow(eps_appointment_service).to receive(:create_draft_appointment)
            .and_return(OpenStruct.new(id: nil))
        end

        include_examples 'returns error response', 'Could not create draft appointment', :unprocessable_entity
      end
    end

    context 'when external service errors bubble up' do
      before do
        allow(ccra_referral_service).to receive(:get_referral).and_return(referral_data)
        allow(appointments_service).to receive(:referral_appointment_already_exists?)
          .and_return({ error: false, exists: false })
        allow(eps_provider_service).to receive(:search_provider_services)
          .and_raise(Common::Exceptions::BackendServiceException.new('TEST_ERROR', {}, 500, 'Test error'))
      end

      it 'allows BackendServiceException to bubble up' do
        expect { subject }.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end

    context 'provider appointment type validation' do
      before do
        allow(ccra_referral_service).to receive(:get_referral).and_return(referral_data)
        allow(appointments_service).to receive(:referral_appointment_already_exists?)
          .and_return({ error: false, exists: false })
        allow(eps_appointment_service).to receive_messages(create_draft_appointment: draft_appointment,
                                                           config: OpenStruct.new(mock_enabled?: false))
        allow(eps_provider_service).to receive(:get_provider_slots).and_return(slots_data)
        allow(current_user).to receive(:vet360_contact_info).and_return(nil)
      end

      context 'when provider has no appointment types' do
        before do
          provider_without_types = OpenStruct.new(id: 'provider-123', appointment_types: [])
          allow(eps_provider_service).to receive(:search_provider_services).and_return(provider_without_types)
        end

        it 'raises BackendServiceException' do
          expect { subject }.to raise_error(Common::Exceptions::BackendServiceException) do |error|
            expect(error.key).to eq('PROVIDER_APPOINTMENT_TYPES_MISSING')
            expect(error.original_status).to eq(502)
            expect(error.original_body).to include('Provider appointment types data is not available')
          end
        end
      end

      context 'when provider has nil appointment types' do
        before do
          provider_with_nil_types = OpenStruct.new(id: 'provider-123', appointment_types: nil)
          allow(eps_provider_service).to receive(:search_provider_services).and_return(provider_with_nil_types)
        end

        it 'raises BackendServiceException' do
          expect { subject }.to raise_error(Common::Exceptions::BackendServiceException) do |error|
            expect(error.key).to eq('PROVIDER_APPOINTMENT_TYPES_MISSING')
            expect(error.original_status).to eq(502)
            expect(error.original_body).to include('Provider appointment types data is not available')
          end
        end
      end

      context 'when provider has no self-schedulable types' do
        before do
          provider_without_self_schedulable = OpenStruct.new(
            id: 'provider-123',
            appointment_types: [{ id: '1', is_self_schedulable: false }, { id: '2' }]
          )
          allow(eps_provider_service).to receive(:search_provider_services)
            .and_return(provider_without_self_schedulable)
        end

        it 'raises BackendServiceException' do
          expect { subject }.to raise_error(Common::Exceptions::BackendServiceException) do |error|
            expect(error.key).to eq('PROVIDER_SELF_SCHEDULABLE_TYPES_MISSING')
            expect(error.original_status).to eq(502)
            expect(error.original_body).to include('No self-schedulable appointment types available')
          end
        end
      end

      context 'when provider has self-schedulable appointment types' do
        before do
          provider_with_self_schedulable = OpenStruct.new(
            id: 'provider-123',
            appointment_types: [
              { id: '1', is_self_schedulable: false },
              { id: '2', is_self_schedulable: true },
              { id: '3', is_self_schedulable: true }
            ]
          )
          allow(eps_provider_service).to receive(:search_provider_services)
            .and_return(provider_with_self_schedulable)
        end

        it 'uses the first self-schedulable appointment type for slot fetching' do
          expect(eps_provider_service).to receive(:get_provider_slots).with(
            'provider-123',
            hash_including(appointmentTypeId: '2')
          )
          expect(subject.id).to eq('draft-123')
        end
      end

      context 'when provider has mixed appointment types with different is_self_schedulable values' do
        before do
          provider_with_mixed_types = OpenStruct.new(
            id: 'provider-123',
            appointment_types: [
              { id: '1' }, # missing property
              { id: '2', is_self_schedulable: nil },
              { id: '3', is_self_schedulable: false },
              { id: '4', is_self_schedulable: true },
              { id: '5', is_self_schedulable: true }
            ]
          )
          allow(eps_provider_service).to receive(:search_provider_services)
            .and_return(provider_with_mixed_types)
        end

        it 'uses the first appointment type where is_self_schedulable is explicitly true' do
          expect(eps_provider_service).to receive(:get_provider_slots).with(
            'provider-123',
            hash_including(appointmentTypeId: '4')
          )
          expect(subject.id).to eq('draft-123')
        end
      end
    end

    context 'metrics and logging validation' do
      it 'logs referral metrics with correct tags' do
        expect(StatsD).to receive(:increment).with(
          'api.vaos.referral_draft_station_id.access',
          tags: [
            'service:community_care_appointments',
            'referring_facility_code:FAC123',
            'provider_npi:1234567890',
            'station_id:no_value'
          ]
        )
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_draft_network_id.access',
          tags: ['service:community_care_appointments', 'network_id:network-1']
        )
        expect(StatsD).to receive(:increment).with(
          'api.vaos.provider_draft_network_id.access',
          tags: ['service:community_care_appointments', 'network_id:network-2']
        )
        subject
      end

      it 'logs provider not found error when provider is nil' do
        allow(eps_provider_service).to receive(:search_provider_services).and_return(nil)
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: Provider not found while creating draft appointment.',
          hash_including(
            provider_npi: '1234567890',
            provider_specialty: 'Cardiology',
            tag: 'Community Care Appointments'
          )
        )
        expect(subject.error).to be_present
        expect(subject.error[:message]).to eq('Provider not found')
      end
    end

    context 'date handling and slot fetching' do
      context 'when referral date is in the past' do
        before do
          past_date_referral = referral_data.dup
          past_date_referral.referral_date = '2020-01-15'
          allow(ccra_referral_service).to receive(:get_referral).and_return(past_date_referral)
        end

        it 'uses current date as start date for slots' do
          expect(eps_provider_service).to receive(:get_provider_slots).with(
            'provider-123',
            hash_including(startOnOrAfter: Date.current.to_time(:utc).iso8601)
          )
          expect(subject.id).to eq('draft-123')
        end
      end

      context 'when referral date is in the future' do
        before do
          # Freeze time to ensure consistent behavior
          travel_to Time.parse('2024-12-01T00:00:00Z')
          future_date_referral = referral_data.dup
          future_date_referral.referral_date = '2025-01-15'
          allow(ccra_referral_service).to receive(:get_referral).and_return(future_date_referral)
        end

        after do
          travel_back
        end

        it 'uses future referral date as start date for slots' do
          expect(eps_provider_service).to receive(:get_provider_slots).with(
            'provider-123',
            hash_including(startOnOrAfter: '2025-01-15T00:00:00Z')
          )
          expect(subject.id).to eq('draft-123')
        end
      end

      context 'when slot fetching includes all required parameters' do
        it 'passes correct parameters to get_provider_slots' do
          expect(eps_provider_service).to receive(:get_provider_slots).with(
            'provider-123',
            hash_including(
              appointmentTypeId: 'type-1',
              startOnOrAfter: kind_of(String),
              startBefore: '2024-04-15T00:00:00Z',
              appointmentId: 'draft-123'
            )
          )
          expect(subject.id).to eq('draft-123')
        end
      end

      context 'when date parsing raises ArgumentError' do
        before do
          allow(Rails.logger).to receive(:error)
        end

        it 'logs error and returns nil for slots' do
          invalid_date_referral = referral_data.dup
          invalid_date_referral.referral_date = 'invalid-date'

          expect(Rails.logger).to receive(:error).with(
            'Community Care Appointments: Error fetching provider slots - Date::Error: invalid date'
          )
          result = subject.send(:fetch_provider_slots, invalid_date_referral, provider_data, 'draft-123')
          expect(result).to be_nil
        end
      end
    end
  end

  describe 'private method testing' do
    describe '#sanitize_log_value' do
      it 'removes spaces and returns sanitized value' do
        result = subject.send(:sanitize_log_value, 'test value with spaces')
        expect(result).to eq('test_value_with_spaces')
      end

      it 'returns no_value for nil input' do
        result = subject.send(:sanitize_log_value, nil)
        expect(result).to eq('no_value')
      end

      it 'returns no_value for empty string' do
        result = subject.send(:sanitize_log_value, '')
        expect(result).to eq('no_value')
      end
    end
  end

  describe '#validate_referral_data' do
    context 'with valid referral data' do
      it 'returns valid true' do
        result = subject.send(:validate_referral_data, referral_data)
        expect(result[:valid]).to be true
        expect(result[:missing_attributes]).to be_empty
      end
    end

    context 'with missing required attributes' do
      let(:invalid_referral) { OpenStruct.new(provider_npi: nil, referral_date: '', expiration_date: '2024-04-15') }

      it 'returns valid false with missing attributes' do
        result = subject.send(:validate_referral_data, invalid_referral)
        expect(result[:valid]).to be false
        expect(result[:missing_attributes]).to include('provider_npi', 'referral_date')
      end
    end
  end
end
