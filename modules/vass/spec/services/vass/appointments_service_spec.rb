# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/vass/appointments_service'

describe Vass::AppointmentsService do
  subject { described_class.build(edipi:, correlation_id:) }

  let(:edipi) { '1234567890' }
  let(:correlation_id) { 'test-correlation-id' }
  let(:veteran_id) { 'vet-123' }
  let(:appointment_id) { 'e61e1a40-1e63-f011-bec2-001dd80351ea' }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    # Stub Settings.vass
    allow(Settings).to receive(:vass).and_return(
      OpenStruct.new(
        auth_url: 'https://login.microsoftonline.us',
        tenant_id: 'test-tenant-id',
        client_id: 'test-client-id',
        client_secret: 'test-client-secret',
        jwt_secret: 'test-jwt-secret',
        scope: 'https://api.va.gov/.default',
        api_url: 'https://api.vass.va.gov',
        subscription_key: 'test-subscription-key',
        service_name: 'vass_api'
      )
    )
  end

  describe '.build' do
    it 'creates a service instance' do
      expect(subject).to be_an_instance_of(Vass::AppointmentsService)
    end

    it 'sets the EDIPI' do
      expect(subject.edipi).to eq(edipi)
    end

    it 'sets the correlation_id' do
      expect(subject.correlation_id).to eq(correlation_id)
    end

    it 'generates correlation_id if not provided' do
      service = described_class.build(edipi:)
      expect(service.correlation_id).to be_present
      expect(service.correlation_id).to match(/^[a-f0-9-]+$/i)
    end
  end

  describe '#get_availability' do
    let(:start_date) { Time.zone.parse('2025-11-27T00:00:00Z') }
    let(:end_date) { Time.zone.parse('2025-12-04T23:59:59Z') }

    context 'when successful' do
      it 'retrieves appointment availability' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_availability_success') do
            result = subject.get_availability(
              start_date:,
              end_date:,
              veteran_id:
            )

            expect(result['success']).to be true
            expect(result['data']['available_time_slots']).to be_an(Array)
            expect(result['data']['appointment_duration']).to eq(30)
          end
        end
      end
    end
  end

  describe '#save_appointment' do
    let(:appointment_params) do
      {
        veteran_id:,
        time_start_utc: Time.zone.parse('2025-11-27T10:00:00Z'),
        time_end_utc: Time.zone.parse('2025-11-27T10:30:00Z'),
        selected_agent_skills: %w[skill-1 skill-2]
      }
    end

    context 'when successful' do
      it 'creates a new appointment' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/save_appointment_success') do
            result = subject.save_appointment(appointment_params:)

            expect(result['success']).to be true
            expect(result['data']['appointment_id']).to eq('e61e1a40-1e63-f011-bec2-001dd80351ea')
          end
        end
      end
    end
  end

  describe '#cancel_appointment' do
    context 'when successful' do
      it 'cancels an appointment' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/cancel_appointment_success') do
            result = subject.cancel_appointment(appointment_id:)

            expect(result['success']).to be true
            expect(result['message']).to eq('Appointment cancelled successfully')
          end
        end
      end
    end

    context 'when appointment not found' do
      it 'raises NotFoundError' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointment_404_not_found') do
            expect do
              subject.get_appointment(appointment_id: 'nonexistent-id')
            end.to raise_error(Vass::Errors::NotFoundError)
          end
        end
      end
    end
  end

  describe '#get_appointment' do
    context 'when successful' do
      it 'retrieves a specific appointment' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointment_success') do
            result = subject.get_appointment(appointment_id:)

            expect(result['success']).to be true
            expect(result['data']['appointment_id']).to eq(appointment_id)
            expect(result['data']['agent_nickname']).to eq('Agent Smith')
          end
        end
      end
    end
  end

  describe '#get_appointments' do
    context 'when successful' do
      it 'retrieves all appointments for a veteran' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointments_success') do
            result = subject.get_appointments(veteran_id:)

            expect(result['success']).to be true
            expect(result['data']['veteran_id']).to eq(veteran_id)
            expect(result['data']['appointments']).to be_an(Array)
            expect(result['data']['appointments'].length).to eq(2)
          end
        end
      end
    end
  end

  describe '#get_veteran_info' do
    let(:veteran_id) { 'da1e1a40-1e63-f011-bec2-001dd80351ea' }
    let(:veteran_response) do
      {
        'success' => true,
        'data' => {
          'first_name' => 'John',
          'last_name' => 'Doe',
          'date_of_birth' => '1990-01-15',
          'edipi' => edipi,
          'notification_email' => 'john.doe@example.com'
        }
      }
    end

    context 'when called without validation params' do
      it 'retrieves veteran information' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/get_veteran_success') do
            result = subject.get_veteran_info(veteran_id:)

            expect(result['success']).to be true
            expect(result['data']['first_name']).to eq('John')
            expect(result['data']['last_name']).to eq('Doe')
            expect(result['data']['edipi']).to eq(edipi)
          end
        end
      end
    end

    context 'when retrieving veteran data' do
      let(:client) { instance_double(Vass::Client) }
      let(:service_with_mock_client) do
        service = described_class.build(edipi:, correlation_id:)
        allow(service).to receive(:client).and_return(client)
        service
      end

      before do
        allow(client).to receive(:get_veteran).and_return(
          double(body: veteran_response, status: 200)
        )
      end

      it 'returns enriched veteran data with contact info' do
        result = service_with_mock_client.get_veteran_info(veteran_id:)

        expect(result['success']).to be true
        expect(result['data']['first_name']).to eq('John')
        expect(result['data']['last_name']).to eq('Doe')
        expect(result['contact_method']).to eq('email')
        expect(result['contact_value']).to eq('john.doe@example.com')
      end

      context 'when contact info is missing' do
        let(:veteran_response_no_email) do
          {
            'success' => true,
            'data' => {
              'first_name' => 'John',
              'last_name' => 'Doe',
              'date_of_birth' => '1990-01-15',
              'edipi' => edipi,
              'notification_email' => nil
            }
          }
        end

        before do
          allow(client).to receive(:get_veteran).and_return(
            double(body: veteran_response_no_email, status: 200)
          )
        end

        it 'raises MissingContactInfoError' do
          expect do
            service_with_mock_client.get_veteran_info(veteran_id:)
          end.to raise_error(
            Vass::Errors::MissingContactInfoError,
            'Veteran contact information not found'
          )
        end
      end

      context 'when API response is invalid' do
        before do
          # Client now validates responses and raises ServiceException for invalid responses
          allow(client).to receive(:get_veteran).and_raise(
            Vass::ServiceException.new(
              Vass::Errors::ERROR_KEY_VASS_ERROR,
              { detail: 'VASS API returned an unsuccessful response' },
              200,
              { 'success' => false, 'message' => 'Veteran not found' }
            )
          )
        end

        it 'raises VassApiError' do
          expect do
            service_with_mock_client.get_veteran_info(veteran_id:)
          end.to raise_error(Vass::Errors::VassApiError)
        end
      end
    end
  end

  describe '#get_agent_skills' do
    context 'when successful' do
      it 'retrieves available agent skills' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/agent_skills/get_agent_skills_success') do
            result = subject.get_agent_skills

            expect(result['success']).to be true
            expect(result['data']['agent_skills']).to be_an(Array)
            expect(result['data']['agent_skills'].length).to eq(3)
            expect(result['data']['agent_skills'].first['skill_name']).to eq('Benefits')
          end
        end
      end
    end

    context 'when client encounters errors' do
      let(:client) { instance_double(Vass::Client) }
      let(:service_with_mock_client) do
        service = described_class.build(edipi:, correlation_id:)
        allow(service).to receive(:client).and_return(client)
        service
      end

      context 'when VASS API returns unsuccessful response' do
        before do
          allow(client).to receive(:get_agent_skills).and_raise(
            Vass::ServiceException.new(
              Vass::Errors::ERROR_KEY_VASS_ERROR,
              { detail: 'VASS API returned an unsuccessful response' },
              503,
              { 'success' => false, 'message' => 'Service temporarily unavailable' }
            )
          )
        end

        it 'raises VassApiError' do
          expect do
            service_with_mock_client.get_agent_skills
          end.to raise_error(Vass::Errors::VassApiError, /VASS API error/)
        end
      end

      context 'when request times out' do
        before do
          allow(client).to receive(:get_agent_skills).and_raise(
            Common::Exceptions::GatewayTimeout.new
          )
        end

        it 'raises ServiceError with timeout message' do
          expect do
            service_with_mock_client.get_agent_skills
          end.to raise_error(Vass::Errors::ServiceError, /Request timeout/)
        end
      end

      context 'when network error occurs' do
        before do
          allow(client).to receive(:get_agent_skills).and_raise(
            Common::Client::Errors::ClientError.new('Connection refused', 500)
          )
        end

        it 'raises ServiceError with HTTP error message' do
          expect do
            service_with_mock_client.get_agent_skills
          end.to raise_error(Vass::Errors::ServiceError, /HTTP error/)
        end
      end

      context 'when VASS API returns 401 unauthorized' do
        before do
          allow(client).to receive(:get_agent_skills).and_raise(
            Vass::ServiceException.new(
              Vass::Errors::ERROR_KEY_VASS_ERROR,
              { detail: 'Authentication failed' },
              401,
              { 'success' => false, 'message' => 'Unauthorized' }
            )
          )
        end

        it 'raises AuthenticationError' do
          expect do
            service_with_mock_client.get_agent_skills
          end.to raise_error(Vass::Errors::AuthenticationError, /Authentication failed/)
        end
      end

      context 'when VASS API returns 404 not found' do
        before do
          allow(client).to receive(:get_agent_skills).and_raise(
            Vass::ServiceException.new(
              Vass::Errors::ERROR_KEY_VASS_ERROR,
              { detail: 'Resource not found' },
              404,
              { 'success' => false, 'message' => 'Not found' }
            )
          )
        end

        it 'raises NotFoundError' do
          expect do
            service_with_mock_client.get_agent_skills
          end.to raise_error(Vass::Errors::NotFoundError, /Resource not found/)
        end
      end
    end
  end

  describe '#get_current_cohort_availability' do
    context 'with current cohort that is unbooked and has available slots' do
      # Freeze time to be within the cassette cohort dates (2026-01-05 to 2026-01-20)
      # and ensure slots (Jan 8, 9) are in the valid "tomorrow to 2 weeks" range
      around do |example|
        Timecop.freeze(DateTime.new(2026, 1, 7).utc) { example.run }
      end

      it 'returns available_slots status with appointment data and filtered slots' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointments_unbooked_cohort') do
            VCR.use_cassette('vass/appointments/get_availability_success') do
              result = subject.get_current_cohort_availability(veteran_id:)

              expect(result[:status]).to eq(:available_slots)
              expect(result[:data]).to be_a(Hash)
              expect(result[:data][:appointment_id]).to be_present
              expect(result[:data][:available_slots]).to be_an(Array)
              expect(result[:data][:available_slots]).not_to be_empty
              # Verify slots have start and end times
              result[:data][:available_slots].each do |slot|
                expect(slot['dtStartUtc']).to be_present
                expect(slot['dtEndUtc']).to be_present
              end
            end
          end
        end
      end
    end

    context 'with current cohort that is already booked' do
      # Freeze time to be within the cassette cohort dates (2026-01-05 to 2026-01-20)
      around do |example|
        Timecop.freeze(DateTime.new(2026, 1, 7).utc) { example.run }
      end

      it 'returns already_booked status without calling availability API' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointments_booked_cohort') do
            result = subject.get_current_cohort_availability(veteran_id:)

            expect(result[:status]).to eq(:already_booked)
            expect(result[:data]).to be_a(Hash)
            expect(result[:data][:appointment_id]).to be_present
            expect(result[:data][:start_utc]).to be_present
            expect(result[:data][:end_utc]).to be_present
          end
        end
      end
    end

    context 'with current cohort but no available slots' do
      # Freeze time to be within the cassette cohort dates (2026-01-05 to 2026-01-20)
      around do |example|
        Timecop.freeze(DateTime.new(2026, 1, 7).utc) { example.run }
      end

      it 'returns no_slots_available status' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointments_unbooked_cohort') do
            VCR.use_cassette('vass/appointments/get_availability_no_slots') do
              result = subject.get_current_cohort_availability(veteran_id:)

              expect(result[:status]).to eq(:no_slots_available)
              expect(result[:data]).to be_a(Hash)
              expect(result[:data][:message]).to eq('No available appointment slots')
            end
          end
        end
      end
    end

    context 'with no current cohort but future cohort exists' do
      # Freeze time to be before the future cassette cohort (2026-02-15 to 2026-02-28)
      around do |example|
        Timecop.freeze(DateTime.new(2026, 1, 7).utc) { example.run }
      end

      it 'returns next_cohort status with future cohort details' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointments_future_cohort_only') do
            result = subject.get_current_cohort_availability(veteran_id:)

            expect(result[:status]).to eq(:next_cohort)
            expect(result[:data]).to be_a(Hash)
            expect(result[:data][:next_cohort]).to be_a(Hash)
            expect(result[:data][:next_cohort][:cohort_start_utc]).to be_present
            expect(result[:data][:next_cohort][:cohort_end_utc]).to be_present
            expect(result[:data][:message]).to include('Booking opens on')
          end
        end
      end
    end

    context 'with no cohorts available' do
      it 'returns no_cohorts status with message' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointments_no_cohorts') do
            result = subject.get_current_cohort_availability(veteran_id:)

            expect(result[:status]).to eq(:no_cohorts)
            expect(result[:data]).to be_a(Hash)
            expect(result[:data][:message]).to eq('Current date outside of appointment cohort date ranges')
          end
        end
      end
    end

    context 'when VASS API returns an error' do
      it 'raises ServiceError' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointments_api_error') do
            expect do
              subject.get_current_cohort_availability(veteran_id:)
            end.to raise_error(Vass::Errors::ServiceError)
          end
        end
      end

      it 'logs the error' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointments_api_error') do
            expect(Rails.logger).to receive(:error).at_least(:once)

            expect do
              subject.get_current_cohort_availability(veteran_id:)
            end.to raise_error(Vass::Errors::ServiceError)
          end
        end
      end
    end
  end

  describe '#whoami' do
    it 'is not yet implemented' do
      expect { subject.whoami }.to raise_error(
        NotImplementedError,
        /whoami endpoint not yet implemented/
      )
    end
  end

  describe 'error handling' do
    context 'when server error occurs' do
      it 'raises ServiceError and logs the error' do
        VCR.use_cassette('vass/oauth_token_success') do
          VCR.use_cassette('vass/appointments/get_appointment_500_server_error') do
            expect(Rails.logger).to receive(:error)

            expect do
              subject.get_appointment(appointment_id:)
            end.to raise_error(Vass::Errors::VassApiError)
          end
        end
      end
    end
  end

  describe 'datetime formatting' do
    it 'formats Time objects to ISO8601' do
      time = Time.zone.parse('2025-11-27T10:00:00Z')
      formatted = subject.send(:format_datetime, time)
      expect(formatted).to eq('2025-11-27T10:00:00Z')
    end

    it 'passes through string datetimes' do
      datetime_str = '2025-11-27T10:00:00Z'
      formatted = subject.send(:format_datetime, datetime_str)
      expect(formatted).to eq(datetime_str)
    end

    it 'returns nil when given nil' do
      formatted = subject.send(:format_datetime, nil)
      expect(formatted).to be_nil
    end
  end

  describe '#parse_utc_time' do
    it 'parses valid UTC time strings' do
      time_string = '2025-11-27T10:00:00Z'
      result = subject.send(:parse_utc_time, time_string, field_name: 'testField')

      expect(result).to be_a(Time)
      expect(result.utc?).to be true
    end

    it 'raises VassApiError and logs when parsing fails' do
      allow(Rails.logger).to receive(:error)

      expect do
        subject.send(:parse_utc_time, 'invalid-date', field_name: 'cohortStartUtc')
      end.to raise_error(Vass::Errors::VassApiError, %r{Invalid date/time format})

      expect(Rails.logger).to have_received(:error).once
    end
  end
end
