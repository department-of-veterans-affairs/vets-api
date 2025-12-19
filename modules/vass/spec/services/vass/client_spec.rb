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
        double('response', env: double('env', body: { 'skills' => [] }))
      )
      subject.instance_variable_set(:@current_oauth_token, oauth_token)

      result = subject.get_agent_skills
      expect(result).to be_present
    end
  end

  describe '#get_veteran' do
    it 'makes request to get veteran data' do
      allow_any_instance_of(Faraday::Connection).to receive(:get).and_return(
        double('response', env: double('env', body: { 'firstName' => 'John' }))
      )
      subject.instance_variable_set(:@current_oauth_token, oauth_token)

      result = subject.get_veteran(edipi:, veteran_id:)
      expect(result).to be_present
    end
  end

  describe '#get_appointment_availability' do
    let(:availability_request) { { 'startDate' => '2024-01-01', 'endDate' => '2024-01-31' } }

    it 'makes request to get appointment availability' do
      allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(
        double('response', env: double('env', body: { 'availableSlots' => [] }))
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
        double('response', env: double('env', body: { 'appointmentId' => 'appt-123' }))
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
        double('response', env: double('env', body: { 'cancelled' => true }))
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
        double('response', env: double('env', body: { 'appointment' => {} }))
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
        double('response', env: double('env', body: { 'appointments' => [] }))
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
          double('response', env: double('env', body: { 'appointments' => [] }))
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
end
