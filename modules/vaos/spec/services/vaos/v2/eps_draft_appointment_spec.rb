# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::V2::EpsDraftAppointment, type: :service do
  subject { described_class.new(current_user) }

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
  end

  # Shared examples for error scenarios
  shared_examples 'raises EpsDraftAppointmentError' do |expected_title, expected_detail_match, expected_status|
    it "raises EpsDraftAppointmentError with #{expected_title}" do
      expect { subject.call(referral_id, referral_consult_id) }
        .to raise_error(VAOS::V2::EpsDraftAppointmentError) do |error|
        expect(error.title).to eq(expected_title)
        expect(error.detail).to match(expected_detail_match)
        expect(error.status_code).to eq(expected_status)
      end
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

  describe '#call' do
    context 'when all services return successfully' do
      before { setup_successful_services }

      it 'returns a successful response with all data' do
        result = subject.call(referral_id, referral_consult_id)

        expect(result.id).to eq('draft-123')
        expect(result.provider).to eq(provider_data)
        expect(result.slots).to eq(slots_data)
        expect(result.drive_time).to eq(drive_time_data)
      end

      it 'calls all services with correct parameters' do
        subject.call(referral_id, referral_consult_id)

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
          result = subject.call(referral_id, referral_consult_id)
          expect(result.drive_time).to be_nil
          expect(eps_provider_service).not_to have_received(:get_drive_times)
        end
      end

      context 'when user has no residential address' do
        before do
          allow(current_user).to receive(:vet360_contact_info).and_return(nil)
        end

        it 'returns nil for drive time' do
          result = subject.call(referral_id, referral_consult_id)
          expect(result.drive_time).to be_nil
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

        include_examples 'raises EpsDraftAppointmentError', 'Invalid referral data',
                         /Required referral data is missing/, :unprocessable_entity
      end

      context 'when referral data is nil' do
        before do
          allow(ccra_referral_service).to receive(:get_referral).and_return(nil)
        end

        include_examples 'raises EpsDraftAppointmentError', 'Invalid referral data', /all required attributes/,
                         :unprocessable_entity
      end

      context 'when Redis connection fails' do
        before do
          allow(ccra_referral_service).to receive(:get_referral).and_raise(Redis::BaseError, 'Connection refused')
        end

        include_examples 'raises EpsDraftAppointmentError', 'Appointment creation failed', 'Redis connection error',
                         :bad_gateway
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

        include_examples 'raises EpsDraftAppointmentError', 'Appointment creation failed',
                         /Error checking existing appointments/, :bad_gateway
      end

      context 'when referral is already used' do
        before do
          allow(appointments_service).to receive(:referral_appointment_already_exists?)
            .and_return({ error: false, exists: true })
        end

        include_examples 'raises EpsDraftAppointmentError', 'Appointment creation failed',
                         'No new appointment created: referral is already used', :unprocessable_entity
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

        include_examples 'raises EpsDraftAppointmentError', 'Appointment creation failed', 'Provider not found',
                         :not_found
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

        include_examples 'raises EpsDraftAppointmentError', 'Appointment creation failed',
                         'Could not create draft appointment', :unprocessable_entity
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
        expect { subject.call(referral_id, referral_consult_id) }
          .to raise_error(Common::Exceptions::BackendServiceException)
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
