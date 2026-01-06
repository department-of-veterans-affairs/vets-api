# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/vass/appointments_service'

describe Vass::AppointmentsService do
  subject { described_class.build(edipi:, correlation_id:) }

  let(:edipi) { '1234567890' }
  let(:correlation_id) { 'test-correlation-id' }
  let(:veteran_id) { 'vet-123' }
  let(:appointment_id) { 'appt-abc123' }

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
        VCR.use_cassette('vass/appointments/get_availability_success') do
          result = subject.get_availability(
            start_date:,
            end_date:,
            veteran_id:
          )

          expect(result['success']).to be true
          expect(result['data']['availableTimeSlots']).to be_an(Array)
          expect(result['data']['appointmentDuration']).to eq(30)
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
        VCR.use_cassette('vass/appointments/save_appointment_success') do
          result = subject.save_appointment(appointment_params:)

          expect(result['success']).to be true
          expect(result['data']['appointmentId']).to eq('appt-abc123')
        end
      end
    end
  end

  describe '#cancel_appointment' do
    context 'when successful' do
      it 'cancels an appointment' do
        VCR.use_cassette('vass/appointments/cancel_appointment_success') do
          result = subject.cancel_appointment(appointment_id:)

          expect(result['success']).to be true
          expect(result['message']).to eq('Appointment cancelled successfully')
        end
      end
    end

    context 'when appointment not found' do
      it 'raises NotFoundError' do
        VCR.use_cassette('vass/appointments/get_appointment_404_not_found') do
          expect do
            subject.get_appointment(appointment_id: 'nonexistent-id')
          end.to raise_error(Vass::Errors::NotFoundError)
        end
      end
    end
  end

  describe '#get_appointment' do
    context 'when successful' do
      it 'retrieves a specific appointment' do
        VCR.use_cassette('vass/appointments/get_appointment_success') do
          result = subject.get_appointment(appointment_id:)

          expect(result['success']).to be true
          expect(result['data']['appointmentId']).to eq(appointment_id)
          expect(result['data']['agentNickname']).to eq('Dr. Smith')
        end
      end
    end
  end

  describe '#get_appointments' do
    context 'when successful' do
      it 'retrieves all appointments for a veteran' do
        VCR.use_cassette('vass/appointments/get_appointments_success') do
          result = subject.get_appointments(veteran_id:)

          expect(result['success']).to be true
          expect(result['data']['veteranId']).to eq(veteran_id)
          expect(result['data']['appointments']).to be_an(Array)
          expect(result['data']['appointments'].length).to eq(2)
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
          'firstName' => 'John',
          'lastName' => 'Doe',
          'dateOfBirth' => '1990-01-15',
          'edipi' => edipi,
          'notificationEmail' => 'john.doe@example.com'
        }
      }
    end

    context 'when called without validation params' do
      it 'retrieves veteran information' do
        VCR.use_cassette('vass/get_veteran_success') do
          result = subject.get_veteran_info(veteran_id:)

          expect(result['success']).to be true
          expect(result['data']['firstName']).to eq('John')
          expect(result['data']['lastName']).to eq('Doe')
          expect(result['data']['edipi']).to eq(edipi)
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
        expect(result['data']['firstName']).to eq('John')
        expect(result['data']['lastName']).to eq('Doe')
        expect(result['contact_method']).to eq('email')
        expect(result['contact_value']).to eq('john.doe@example.com')
      end

      context 'when contact info is missing' do
        let(:veteran_response_no_email) do
          {
            'success' => true,
            'data' => {
              'firstName' => 'John',
              'lastName' => 'Doe',
              'dateOfBirth' => '1990-01-15',
              'edipi' => edipi,
              'notificationEmail' => nil
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
        let(:invalid_response) do
          {
            'success' => false,
            'message' => 'Veteran not found'
          }
        end

        before do
          allow(client).to receive(:get_veteran).and_return(
            double(body: invalid_response, status: 200)
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
        VCR.use_cassette('vass/get_agent_skills_success') do
          result = subject.get_agent_skills

          expect(result['success']).to be true
          expect(result['data']['agentSkills']).to be_an(Array)
          expect(result['data']['agentSkills'].length).to eq(4)
          expect(result['data']['agentSkills'].first['skillName']).to eq('Mental Health Counseling')
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
        VCR.use_cassette('vass/get_appointment_500_server_error') do
          expect(Rails.logger).to receive(:error)

          expect do
            subject.get_appointment(appointment_id:)
          end.to raise_error(Vass::Errors::VassApiError)
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

  describe '#get_current_cohort_availability' do
    context 'when current cohort is unbooked' do
      it 'returns available_slots status with appointment data' do
        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/get_appointments_unbooked_cohort', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_availability_success', match_requests_on: %i[method uri]) do
              result = subject.get_current_cohort_availability(veteran_id:)

              expect(result[:status]).to eq(:available_slots)
              expect(result[:data][:appointment_id]).to be_present
              expect(result[:data][:cohort][:cohort_start_utc]).to be_present
              expect(result[:data][:cohort][:cohort_end_utc]).to be_present
              expect(result[:data][:available_slots]).to be_an(Array)
              expect(result[:data][:available_slots]).not_to be_empty
            end
          end
        end
      end
    end

    context 'when current cohort is already booked' do
      it 'returns already_booked status with appointment details' do
        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/get_appointments_booked_cohort', match_requests_on: %i[method uri]) do
            result = subject.get_current_cohort_availability(veteran_id:)

            expect(result[:status]).to eq(:already_booked)
            expect(result[:data][:appointment_id]).to be_present
            expect(result[:data][:start_utc]).to be_present
            expect(result[:data][:end_utc]).to be_present
          end
        end
      end
    end

    context 'when no current cohort exists (future cohorts only)' do
      it 'returns next_cohort status with next cohort details' do
        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/get_appointments_future_cohort_only',
                           match_requests_on: %i[method uri]) do
            result = subject.get_current_cohort_availability(veteran_id:)

            expect(result[:status]).to eq(:next_cohort)
            expect(result[:data][:message]).to include('Booking opens on')
            expect(result[:data][:next_cohort][:cohort_start_utc]).to be_present
            expect(result[:data][:next_cohort][:cohort_end_utc]).to be_present
          end
        end
      end
    end

    context 'when no cohorts are available' do
      it 'returns no_cohorts status with message' do
        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/get_appointments_no_cohorts', match_requests_on: %i[method uri]) do
            result = subject.get_current_cohort_availability(veteran_id:)

            expect(result[:status]).to eq(:no_cohorts)
            expect(result[:data][:message]).to eq('Current date outside of appointment cohort date ranges')
          end
        end
      end
    end

    context 'when multiple cohorts exist' do
      it 'selects the current cohort (not past or future)' do
        VCR.use_cassette('vass/oauth_token_success', match_requests_on: %i[method uri]) do
          VCR.use_cassette('vass/appointments/get_appointments_unbooked_cohort', match_requests_on: %i[method uri]) do
            VCR.use_cassette('vass/appointments/get_availability_no_slots', match_requests_on: %i[method uri]) do
              result = subject.get_current_cohort_availability(veteran_id:)

              expect(result[:status]).to eq(:no_slots_available)
              expect(result[:data][:message]).to eq('No available appointment slots')
            end
          end
        end
      end
    end
  end
end
