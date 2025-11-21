# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/vass/client'

describe Vass::Client do
  subject { described_class.new }

  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:correlation_id) { 'test-correlation-id' }
  let(:oauth_token) { 'test-oauth-token' }
  let(:edipi) { '1234567890' }
  let(:veteran_id) { 'vet-123' }

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe '.new' do
    it 'creates a client instance' do
      expect(subject).to be_an_instance_of(Vass::Client)
    end

    it 'generates a correlation ID if not provided' do
      client = described_class.new
      expect(client.instance_variable_get(:@correlation_id)).to be_present
    end

    it 'uses provided correlation ID' do
      client = described_class.new(correlation_id:)
      expect(client.instance_variable_get(:@correlation_id)).to eq(correlation_id)
    end
  end

  describe 'attributes' do
    it 'has access to settings' do
      expect(subject.settings).to eq(Settings.vass)
    end

    it 'delegates settings methods' do
      expect(subject.client_id).to eq(Settings.vass.client_id)
      expect(subject.auth_url).to eq(Settings.vass.auth_url)
      expect(subject.api_url).to eq(Settings.vass.api_url)
    end
  end

  describe '#oauth_token_request' do
    let(:mock_response) { double('response', body: { 'access_token' => oauth_token }) }

    before do
      allow(subject).to receive(:perform).and_return(mock_response)
    end

    it 'makes OAuth token request with correct parameters' do
      expected_body = URI.encode_www_form({
                                            client_id: Settings.vass.client_id,
                                            client_secret: Settings.vass.client_secret,
                                            scope: Settings.vass.scope,
                                            grant_type: 'client_credentials'
                                          })

      expect(subject).to receive(:perform).with(
        :post,
        "#{Settings.vass.tenant_id}/oauth2/v2.0/token",
        expected_body,
        { 'Content-Type' => 'application/x-www-form-urlencoded' },
        { server_url: Settings.vass.auth_url }
      )

      subject.oauth_token_request
    end
  end

  describe '#get_agent_skills' do
    let(:mock_response) { double('response', body: { 'skills' => [] }) }

    before do
      allow(subject).to receive(:ensure_oauth_token!)
      allow(subject).to receive(:perform).and_return(mock_response)
      subject.instance_variable_set(:@current_oauth_token, oauth_token)
    end

    it 'makes GET request to agent skills endpoint' do
      expect(subject).to receive(:perform).with(
        :get,
        'api/GetAgentSkills',
        nil,
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{oauth_token}",
          'correlationId' => subject.instance_variable_get(:@correlation_id)
        )
      )

      subject.get_agent_skills
    end
  end

  describe '#get_veteran' do
    let(:mock_response) { double('response', body: { 'firstName' => 'John', 'lastName' => 'Doe' }) }

    before do
      allow(subject).to receive(:ensure_oauth_token!)
      allow(subject).to receive(:perform).and_return(mock_response)
      subject.instance_variable_set(:@current_oauth_token, oauth_token)
    end

    it 'makes GET request to veteran endpoint with required headers' do
      expect(subject).to receive(:perform).with(
        :get,
        'api/GetVeteran',
        nil,
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{oauth_token}",
          'EDIPI' => edipi,
          'veteranId' => veteran_id,
          'correlationId' => subject.instance_variable_get(:@correlation_id)
        )
      )

      subject.get_veteran(edipi:, veteran_id:)
    end
  end

  describe '#get_appointment_availability' do
    let(:availability_request) { { 'startDate' => '2024-01-01', 'endDate' => '2024-01-31' } }
    let(:mock_response) { double('response', body: { 'availableSlots' => [] }) }

    before do
      allow(subject).to receive(:ensure_oauth_token!)
      allow(subject).to receive(:perform).and_return(mock_response)
      subject.instance_variable_set(:@current_oauth_token, oauth_token)
    end

    it 'makes POST request to appointment availability endpoint' do
      expect(subject).to receive(:perform).with(
        :post,
        'api/AppointmentAvailability',
        availability_request,
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{oauth_token}",
          'EDIPI' => edipi,
          'correlationId' => subject.instance_variable_get(:@correlation_id)
        )
      )

      subject.get_appointment_availability(edipi:, availability_request:)
    end
  end

  describe '#save_appointment' do
    let(:appointment_data) { { 'startTime' => '2024-01-01T10:00:00Z', 'skillId' => '123' } }
    let(:mock_response) { double('response', body: { 'appointmentId' => 'appt-123' }) }

    before do
      allow(subject).to receive(:ensure_oauth_token!)
      allow(subject).to receive(:perform).and_return(mock_response)
      subject.instance_variable_set(:@current_oauth_token, oauth_token)
    end

    it 'makes POST request to save appointment endpoint' do
      expect(subject).to receive(:perform).with(
        :post,
        'api/SaveAppointment',
        appointment_data,
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{oauth_token}",
          'EDIPI' => edipi,
          'correlationId' => subject.instance_variable_get(:@correlation_id)
        )
      )

      subject.save_appointment(edipi:, appointment_data:)
    end
  end

  describe '#cancel_appointment' do
    let(:appointment_id) { 'appt-123' }
    let(:mock_response) { double('response', body: { 'cancelled' => true }) }

    before do
      allow(subject).to receive(:ensure_oauth_token!)
      allow(subject).to receive(:perform).and_return(mock_response)
      subject.instance_variable_set(:@current_oauth_token, oauth_token)
    end

    it 'makes POST request to cancel appointment endpoint with appointment ID' do
      expected_request_body = { appointmentId: appointment_id }

      expect(subject).to receive(:perform).with(
        :post,
        'api/CancelAppointment',
        expected_request_body,
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{oauth_token}",
          'EDIPI' => edipi,
          'correlationId' => subject.instance_variable_get(:@correlation_id)
        )
      )

      subject.cancel_appointment(edipi:, appointment_id:)
    end
  end

  describe '#get_veteran_appointment' do
    let(:appointment_id) { 'appt-123' }
    let(:mock_response) { double('response', body: { 'appointment' => {} }) }

    before do
      allow(subject).to receive(:ensure_oauth_token!)
      allow(subject).to receive(:perform).and_return(mock_response)
      subject.instance_variable_set(:@current_oauth_token, oauth_token)
    end

    it 'makes GET request to appointment endpoint with appointmentId header' do
      expect(subject).to receive(:perform).with(
        :get,
        'api/GetVeteranAppointment',
        nil,
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{oauth_token}",
          'EDIPI' => edipi,
          'appointmentId' => appointment_id,
          'correlationId' => subject.instance_variable_get(:@correlation_id)
        )
      )

      subject.get_veteran_appointment(edipi:, appointment_id:)
    end
  end

  describe '#get_veteran_appointments' do
    let(:veteran_id) { 'vet-123' }
    let(:mock_response) { double('response', body: { 'appointments' => [] }) }

    before do
      allow(subject).to receive(:ensure_oauth_token!)
      allow(subject).to receive(:perform).and_return(mock_response)
      subject.instance_variable_set(:@current_oauth_token, oauth_token)
    end

    it 'makes POST request to veteran appointments endpoint with correct body' do
      expect(subject).to receive(:perform).with(
        :post,
        'api/GetVeteranAppointments',
        {
          'correlationId' => subject.instance_variable_get(:@correlation_id),
          'veteranId' => veteran_id
        },
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{oauth_token}",
          'EDIPI' => edipi,
          'correlationId' => subject.instance_variable_get(:@correlation_id)
        )
      )

      subject.get_veteran_appointments(edipi:, veteran_id:)
    end
  end

  describe 'OAuth token management' do
    let(:redis_client) { instance_double(Vass::RedisClient) }

    before do
      allow(Vass::RedisClient).to receive(:build).and_return(redis_client)
      allow(redis_client).to receive(:token).and_return(nil)
      allow(redis_client).to receive(:save_token)
    end

    context 'when token is cached' do
      before do
        allow(redis_client).to receive(:token).and_return(oauth_token)
      end

      it 'uses cached token' do
        subject.send(:ensure_oauth_token!)
        expect(subject.instance_variable_get(:@current_oauth_token)).to eq(oauth_token)
      end
    end

    context 'when token needs to be minted' do
      let(:mock_response) { double('response', body: { 'access_token' => oauth_token }) }

      before do
        allow(subject).to receive(:oauth_token_request).and_return(mock_response)
      end

      it 'requests new token and caches it' do
        expect(redis_client).to receive(:save_token).with(token: oauth_token)

        subject.send(:ensure_oauth_token!)
        expect(subject.instance_variable_get(:@current_oauth_token)).to eq(oauth_token)
      end
    end

    context 'when OAuth response is missing access_token' do
      let(:mock_response) { double('response', body: {}) }

      before do
        allow(subject).to receive(:oauth_token_request).and_return(mock_response)
      end

      it 'raises BackendServiceException' do
        expect do
          subject.send(:ensure_oauth_token!)
        end.to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end
end
