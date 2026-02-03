# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/vass/client'
require_relative '../../support/vass_settings_helper'

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

    # Stub Settings.vass for token encryption
    stub_vass_settings
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
    it 'makes OAuth token request and returns response' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
        double('response', env: double('env', body: { 'access_token' => 'token' }))
      )

      result = subject.oauth_token_request
      expect(result).to be_present
    end
  end

  describe '#get_agent_skills' do
    it 'makes request to get agent skills' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
        double('response',
               env: double('env', body: { 'success' => true, 'data' => { 'agentSkills' => [] } }, status: 200))
      )
      subject.instance_variable_set(:@current_oauth_token, oauth_token)

      result = subject.get_agent_skills
      expect(result).to be_present
    end
  end

  describe '#get_veteran' do
    it 'makes request to get veteran data' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
        double('response',
               env: double('env', body: { 'success' => true, 'data' => { 'firstName' => 'John' } }, status: 200))
      )
      subject.instance_variable_set(:@current_oauth_token, oauth_token)

      result = subject.get_veteran(veteran_id:)
      expect(result).to be_present
    end
  end

  describe '#get_appointment_availability' do
    let(:availability_request) { { 'startDate' => '2024-01-01', 'endDate' => '2024-01-31' } }

    it 'makes request to get appointment availability' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
        double('response',
               env: double('env', body: { 'success' => true, 'data' => { 'availableSlots' => [] } }, status: 200))
      )
      subject.instance_variable_set(:@current_oauth_token, oauth_token)

      result = subject.get_appointment_availability(edipi:, availability_request:)
      expect(result).to be_present
    end
  end

  describe '#save_appointment' do
    let(:appointment_data) { { 'startTime' => '2024-01-01T10:00:00Z', 'skillId' => '123' } }

    it 'makes request to save appointment' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
        double('response',
               env: double('env', body: { 'success' => true, 'data' => { 'appointmentId' => 'appt-123' } },
                                  status: 200))
      )
      subject.instance_variable_set(:@current_oauth_token, oauth_token)

      result = subject.save_appointment(edipi:, appointment_data:)
      expect(result).to be_present
    end
  end

  describe '#cancel_appointment' do
    let(:appointment_id) { 'appt-123' }

    it 'makes request to cancel appointment' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
        double('response',
               env: double('env', body: { 'success' => true, 'data' => { 'cancelled' => true } }, status: 200))
      )
      subject.instance_variable_set(:@current_oauth_token, oauth_token)

      result = subject.cancel_appointment(edipi:, appointment_id:)
      expect(result).to be_present
    end
  end

  describe '#get_veteran_appointment' do
    let(:appointment_id) { 'appt-123' }

    it 'makes request to get veteran appointment' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
        double('response',
               env: double('env', body: { 'success' => true, 'data' => { 'appointment' => {} } }, status: 200))
      )
      subject.instance_variable_set(:@current_oauth_token, oauth_token)

      result = subject.get_veteran_appointment(edipi:, appointment_id:)
      expect(result).to be_present
    end
  end

  describe '#get_veteran_appointments' do
    let(:veteran_id) { 'vet-123' }

    it 'makes request to get veteran appointments' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
        double('response',
               env: double('env', body: { 'success' => true, 'data' => { 'appointments' => [] } }, status: 200))
      )
      subject.instance_variable_set(:@current_oauth_token, oauth_token)

      result = subject.get_veteran_appointments(edipi:, veteran_id:)
      expect(result).to be_present
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
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
          double('response', env: double('env', body: { 'access_token' => oauth_token }))
        )
      end

      it 'requests new token and caches it' do
        expect(redis_client).to receive(:save_token).with(token: oauth_token)

        subject.send(:ensure_oauth_token!)
        expect(subject.instance_variable_get(:@current_oauth_token)).to eq(oauth_token)
      end
    end

    context 'when OAuth response is missing access_token' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
          double('response', env: double('env', body: {}, status: 200))
        )
      end

      it 'raises Vass::ServiceException' do
        expect do
          subject.send(:ensure_oauth_token!)
        end.to raise_error(Vass::ServiceException)
      end
    end

    context 'server_url option' do
      let(:auth_url) { 'https://login.microsoftonline.com' }
      let(:api_url) { 'https://api.vass.va.gov' }

      before do
        allow(Settings.vass).to receive_messages(auth_url:, api_url:)
      end

      it 'uses auth_url for OAuth requests' do
        expect(subject.config).to receive(:connection).with(server_url: auth_url).and_call_original

        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
          double('response', env: double('env', body: { 'access_token' => oauth_token, 'expires_in' => 3600 }))
        )

        subject.send(:oauth_token_request)
      end

      it 'uses base_path for regular API requests' do
        expect(subject.config).to receive(:connection).and_call_original

        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
          double('response',
                 env: double('env', body: { 'success' => true, 'data' => { 'appointments' => [] } }, status: 200))
        )
        subject.instance_variable_set(:@current_oauth_token, oauth_token)

        subject.get_veteran_appointments(edipi:, veteran_id:)
      end

      it 'connection method uses connection pooling for different URLs' do
        conn1 = subject.config.connection(server_url: auth_url)
        conn2 = subject.config.connection(server_url: auth_url)
        conn3 = subject.config.connection(server_url: api_url)

        # Same URL should return same connection instance (pooling)
        expect(conn1).to be(conn2)

        # Different URL should return different connection instance
        expect(conn1).not_to be(conn3)
      end
    end
  end

  describe 'response validation' do
    before do
      subject.instance_variable_set(:@current_oauth_token, oauth_token)
    end

    context 'when response has success: true' do
      it 'returns response without raising error' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
          double('response', env: double('env', body: { 'success' => true, 'data' => {} }, status: 200))
        )

        expect { subject.get_agent_skills }.not_to raise_error
      end
    end

    context 'when response has success: false' do
      it 'raises ServiceException' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
          double('response', env: double('env', body: { 'success' => false, 'message' => 'Error' }, status: 200))
        )

        expect { subject.get_agent_skills }.to raise_error(Vass::ServiceException) do |error|
          expect(error.key).to eq(Vass::Errors::ERROR_KEY_VASS_ERROR)
          expect(error.response_values[:detail]).to eq('VASS API returned an unsuccessful response')
          expect(error.original_status).to eq(200)
        end
      end
    end

    context 'when response body is not a hash' do
      it 'raises ServiceException' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
          double('response', env: double('env', body: 'invalid response', status: 200))
        )

        expect { subject.get_agent_skills }.to raise_error(Vass::ServiceException) do |error|
          expect(error.key).to eq(Vass::Errors::ERROR_KEY_VASS_ERROR)
          expect(error.response_values[:detail]).to eq('VASS API returned an unsuccessful response')
        end
      end
    end

    context 'when response body is nil' do
      it 'raises ServiceException' do
        allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
          double('response', env: double('env', body: nil, status: 200))
        )

        expect { subject.get_agent_skills }.to raise_error(Vass::ServiceException)
      end
    end

    context 'when making OAuth token request' do
      it 'skips validation for OAuth endpoint' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
          double('response', env: double('env', body: { 'access_token' => 'token' }, status: 200))
        )

        # OAuth response doesn't have 'success' field, but shouldn't raise error
        expect { subject.oauth_token_request }.not_to raise_error
      end
    end
  end
end
