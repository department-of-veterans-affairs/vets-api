# frozen_string_literal: true

require 'rails_helper'

describe Eps::AppointmentService do
  subject(:service) { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234', icn:) }
  let(:config) { instance_double(Eps::Configuration) }
  let(:headers) { { 'Authorization' => 'Bearer token123' } }

  let(:appointment_id) { 'appointment-123' }
  let(:icn) { '123ICN' }

  before do
    allow(config).to receive(:base_path).and_return('api/v1')
    allow_any_instance_of(Eps::BaseService).to receive_messages(config:, headers:)
    allow_any_instance_of(Eps::BaseService).to receive(:patient_id).and_return(icn)
  end

  describe '#get_appointment' do
    let(:success_response) do
      double('Response', status: 200, body: { 'id' => appointment_id,
                                              'state' => 'submitted',
                                              'patientId' => icn })
    end

    context 'when the request is successful' do
      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(success_response)
      end

      it 'returns appointment details' do
        response = service.get_appointment(appointment_id:)
        expect(response.id).to eq(appointment_id)
        expect(response.state).to eq('submitted')
        expect(response.patientId).to eq(icn)
      end

      context 'when retrieve_latest_details is true' do
        before do
          expect_any_instance_of(VAOS::SessionService).to receive(:perform)
            .with(:get, "/#{config.base_path}/appointments/#{appointment_id}?retrieveLatestDetails=true", {}, headers)
            .and_return(success_response)
        end

        it 'includes the retrieveLatestDetails query parameter' do
          response = service.get_appointment(appointment_id:, retrieve_latest_details: true)
          expect(response.id).to eq(appointment_id)
        end
      end
    end

    context 'when the endpoint fails to return appointments' do
      let(:failed_appt_response) do
        double('Response', status: 500, body: 'Unknown service exception')
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, failed_appt_response.status,
                                                        failed_appt_response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'throws exception' do
        expect { service.get_appointment(appointment_id:) }.to raise_error(Common::Exceptions::BackendServiceException,
                                                                           /VA900/)
      end
    end
  end

  describe 'get_appointments' do
    context 'when requesting appointments for a logged in user' do
      let(:successful_appt_response) do
        double('Response', status: 200, body: { 'count' => 1,
                                                'appointments' => [
                                                  {
                                                    'id' => appointment_id,
                                                    'state' => 'booked',
                                                    'patientId' => icn
                                                  }
                                                ] })
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(successful_appt_response)
      end
    end

    context 'when the endpoint fails to return appointments' do
      let(:failed_appt_response) do
        double('Response', status: 500, body: 'Unknown service exception')
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, failed_appt_response.status,
                                                        failed_appt_response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'throws exception' do
        expect { service.get_appointments }.to raise_error(Common::Exceptions::BackendServiceException,
                                                           /VA900/)
      end
    end
  end

  describe 'create_draft_appointment_with_response' do
    let(:referral_id) { 'test-referral-id' }
    let(:user_coordinates) { { latitude: 38.9072, longitude: -77.0369 } }
    let(:pagination_params) { { page: 1, per_page: 10 } }
    let(:referral_data) do
      {
        provider_id: 'provider-123',
        appointment_type_id: 'ov',
        start_date: '2025-01-01T00:00:00Z',
        end_date: '2025-01-31T00:00:00Z'
      }
    end
    let(:draft_appointment) { OpenStruct.new(id: appointment_id, state: 'draft', patient_id: icn) }
    let(:provider_service_response) { OpenStruct.new(id: 'provider-123', name: 'Test Provider', location: { latitude: 38.8977, longitude: -77.0365 }) }
    let(:slots_response) { [{ id: 'slot-1', start_time: '2025-01-15T09:00:00Z', end_time: '2025-01-15T09:30:00Z' }] }
    let(:drive_time_response) { { 'provider-123' => { distance: 5.2, duration: 15 } } }

    let(:successful_draft_appt_response) do
      double('Response', status: 200, body: { 'id' => appointment_id,
                                              'state' => 'draft',
                                              'patientId' => icn })
    end

    before do
      redis_client = instance_double(Eps::RedisClient)
      allow(Eps::RedisClient).to receive(:new).and_return(redis_client)
      allow(redis_client).to receive(:fetch_referral_attributes).and_return(referral_data)

      appointments_service = instance_double(VAOS::V2::AppointmentsService)
      allow(VAOS::V2::AppointmentsService).to receive(:new).and_return(appointments_service)
      allow(appointments_service).to receive(:referral_appointment_already_exists?).and_return({ exists: false })

      allow_any_instance_of(VAOS::SessionService).to receive(:perform)
        .with(:post, "/#{config.base_path}/appointments", { patientId: icn, referralId: referral_id }, headers)
        .and_return(successful_draft_appt_response)

      provider_service = instance_double(Eps::ProviderService)
      allow(Eps::ProviderService).to receive(:new).and_return(provider_service)
      allow(provider_service).to receive(:get_provider_service).and_return(provider_service_response)
      allow(provider_service).to receive(:get_provider_slots).and_return(slots_response)
      allow(provider_service).to receive(:get_drive_times).and_return(drive_time_response)
    end

    context 'when creating draft appointment with all dependencies successful' do
      it 'returns a successful response with draft appointment, provider, slots, and drive time data' do
        result = service.create_draft_appointment_with_response(
          referral_id:,
          user_coordinates:,
          pagination_params:
        )

        expect(result).to be_a(OpenStruct)
        expect(result.id).to eq(appointment_id)
        expect(result.provider).to eq(provider_service_response)
        expect(result.slots).to eq(slots_response)
        expect(result.drive_time).to eq(drive_time_response)
      end
    end

    context 'when the endpoint fails' do
      let(:failed_response) do
        double('Response', status: 500, body: 'Unknown service exception')
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, failed_response.status,
                                                        failed_response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'returns an error response hash' do
        result = service.create_draft_appointment_with_response(
          referral_id:,
          user_coordinates:
        )

        expect(result).to be_a(Hash)
        expect(result[:error]).to be(true)
        expect(result[:status]).to eq(:bad_request)
        expect(result[:json][:errors]).to be_a(Array)
        expect(result[:json][:errors].first[:title]).to eq('Error creating draft appointment')
        expect(result[:json][:errors].first[:detail]).to include('Unexpected error creating draft appointment')
      end
    end

    context 'when Redis cache fails' do
      before do
        redis_client = instance_double(Eps::RedisClient)
        allow(Eps::RedisClient).to receive(:new).and_return(redis_client)
        allow(redis_client).to receive(:fetch_referral_attributes).and_raise(Redis::BaseError.new('Connection refused'))
      end

      it 'returns an error about cache service' do
        result = service.create_draft_appointment_with_response(
          referral_id:,
          user_coordinates:
        )

        expect(result[:success]).to be(false)
        expect(result[:error]).to be(true)
        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:json][:errors].first[:title]).to eq('Error fetching referral data from cache')
        expect(result[:json][:errors].first[:detail]).to include('Unable to connect to cache service')
      end
    end

    context 'when referral data is invalid' do
      let(:incomplete_referral_data) do
        {
          provider_id: 'provider-123'
        }
      end

      before do
        redis_client = instance_double(Eps::RedisClient)
        allow(Eps::RedisClient).to receive(:new).and_return(redis_client)
        allow(redis_client).to receive(:fetch_referral_attributes).and_return(incomplete_referral_data)
      end

      it 'returns an error about invalid referral data' do
        result = service.create_draft_appointment_with_response(
          referral_id:,
          user_coordinates:
        )

        expect(result[:success]).to be(false)
        expect(result[:error]).to be(true)
        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:json][:errors].first[:title]).to eq('Invalid referral data')
        expect(result[:json][:errors].first[:detail]).to include('Required referral data is missing or incomplete')
      end
    end

    context 'when the referral is already in use' do
      before do
        appointments_service = instance_double(VAOS::V2::AppointmentsService)
        allow(VAOS::V2::AppointmentsService).to receive(:new).and_return(appointments_service)
        allow(appointments_service).to receive(:referral_appointment_already_exists?).and_return({ exists: true })
      end

      it 'returns an error that referral is already used' do
        result = service.create_draft_appointment_with_response(
          referral_id:,
          user_coordinates:
        )

        expect(result[:success]).to be(false)
        expect(result[:error]).to be(true)
        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:json][:errors].first[:title]).to eq('Referral already used')
        expect(result[:json][:errors].first[:detail]).to include('No new appointment created: referral is already used')
      end
    end

    context 'when checking referral usage returns an error' do
      before do
        appointments_service = instance_double(VAOS::V2::AppointmentsService)
        allow(VAOS::V2::AppointmentsService).to receive(:new).and_return(appointments_service)
        allow(appointments_service).to receive(:referral_appointment_already_exists?)
          .and_return({ error: true, failures: ['Network error'] })
      end

      it 'returns an error about checking appointments' do
        result = service.create_draft_appointment_with_response(
          referral_id:,
          user_coordinates:
        )

        expect(result[:success]).to be(false)
        expect(result[:error]).to be(true)
        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:json][:errors].first[:title]).to eq('Error checking appointments')
        expect(result[:json][:errors].first[:detail]).to include('Error checking if referral is already used')
      end
    end

    context 'when provider service cannot be retrieved' do
      before do
        provider_service = instance_double(Eps::ProviderService)
        allow(Eps::ProviderService).to receive(:new).and_return(provider_service)
        allow(provider_service).to receive(:get_provider_service)
          .and_raise(Common::Exceptions::BackendServiceException.new('PROVIDER_ERROR', status: 404))
      end

      it 'returns an error about provider information' do
        result = service.create_draft_appointment_with_response(
          referral_id:,
          user_coordinates:
        )

        expect(result[:success]).to be(false)
        expect(result[:error]).to be(true)
        expect(result[:status]).to eq(:not_found)
        expect(result[:json][:errors].first[:title]).to eq('Error fetching provider information')
        expect(result[:json][:errors].first[:detail]).to include('Unexpected error fetching provider information')
      end
    end

    context 'when provider slots cannot be retrieved' do
      before do
        provider_service = instance_double(Eps::ProviderService)
        allow(Eps::ProviderService).to receive(:new).and_return(provider_service)
        allow(provider_service).to receive(:get_provider_service).and_return(provider_service_response)
        allow(provider_service).to receive(:get_provider_slots)
          .and_raise(Common::Exceptions::BackendServiceException.new(nil, {}, 500, 'Provider slots error'))
      end

      it 'returns an error about provider slots' do
        result = service.create_draft_appointment_with_response(
          referral_id:,
          user_coordinates:
        )

        expect(result[:success]).to be(false)
        expect(result[:error]).to be(true)
        expect(result[:status]).to eq(:bad_gateway)
        expect(result[:json][:errors].first[:title]).to eq('Error fetching provider slots')
        expect(result[:json][:errors].first[:detail]).to include('Unexpected error fetching provider slots')
      end
    end
  end

  describe '#submit_appointment' do
    let(:valid_params) do
      {
        network_id: 'network-123',
        provider_service_id: 'provider-456',
        slot_ids: ['slot-789'],
        referral_number: 'REF-001'
      }
    end

    context 'with valid parameters' do
      let(:successful_response) do
        double('Response', status: 200, body: { 'id' => appointment_id,
                                                'state' => 'draft',
                                                'patientId' => icn })
      end

      it 'submits the appointment successfully' do
        expected_payload = {
          network_id: valid_params[:network_id],
          provider_service_id: valid_params[:provider_service_id],
          slot_ids: valid_params[:slot_ids],
          referral: {
            referral_number: valid_params[:referral_number]
          }
        }

        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:post, "/#{config.base_path}/appointments/#{appointment_id}/submit", expected_payload, kind_of(Hash))
          .and_return(successful_response)

        exp_response = OpenStruct.new(successful_response.body)

        expect(service.submit_appointment(appointment_id, valid_params)).to eq(exp_response)
      end

      it 'includes additional patient attributes when provided' do
        patient_attributes = { name: 'John Doe', email: 'john@example.com' }
        params_with_attributes = valid_params.merge(additional_patient_attributes: patient_attributes)

        expected_payload = {
          network_id: valid_params[:network_id],
          provider_service_id: valid_params[:provider_service_id],
          slot_ids: valid_params[:slot_ids],
          referral: {
            referral_number: valid_params[:referral_number]
          },
          additional_patient_attributes: patient_attributes
        }

        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:post, "/#{config.base_path}/appointments/#{appointment_id}/submit", expected_payload, kind_of(Hash))
          .and_return(successful_response)

        service.submit_appointment(appointment_id, params_with_attributes)
      end
    end

    context 'with invalid parameters' do
      it 'raises ArgumentError when appointment_id is nil' do
        expect { service.submit_appointment(nil, valid_params) }
          .to raise_error(ArgumentError, 'appointment_id is required and cannot be blank')
      end

      it 'raises ArgumentError when appointment_id is empty' do
        expect { service.submit_appointment('', valid_params) }
          .to raise_error(ArgumentError, 'appointment_id is required and cannot be blank')
      end

      it 'raises ArgumentError when appointment_id is blank' do
        expect { service.submit_appointment('   ', valid_params) }
          .to raise_error(ArgumentError, 'appointment_id is required and cannot be blank')
      end

      it 'raises ArgumentError when required parameters are missing' do
        invalid_params = valid_params.except(:network_id)

        expect { service.submit_appointment(appointment_id, invalid_params) }
          .to raise_error(ArgumentError, /Missing required parameters: network_id/)
      end

      it 'raises ArgumentError when multiple required parameters are missing' do
        invalid_params = valid_params.except(:network_id, :provider_service_id)

        expect { service.submit_appointment(appointment_id, invalid_params) }
          .to raise_error(ArgumentError, /Missing required parameters: network_id, provider_service_id/)
      end
    end

    context 'when API returns an error' do
      let(:response) { double('Response', status: 500, body: 'Unknown service exception') }
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, response.status, response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'returns the error response' do
        expect do
          service.submit_appointment(appointment_id, valid_params)
        end.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end
  end
end
