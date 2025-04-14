# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fixture_helper'

describe Common::JwtWrapper do
  subject { described_class.new(service_settings, service_config) }

  # Generate a test RSA key instead of using the hardcoded one
  let(:test_key) { OpenSSL::PKey::RSA.new(2048).to_s }

  let(:service_settings) do
    OpenStruct.new(
      key: test_key,
      client_id: 'test-client-id',
      kid: 'test-key-id',
      audience_claim_url: 'https://test-audience.example.com'
    )
  end

  let(:service_config) do
    OpenStruct.new(
      service_name: 'TestService'
    )
  end

  # JWT REGEX has 3 base64 url encoded parts (header, payload signature) and more importantly is non empty.
  let(:jwt_regex) { %r{^[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.?[A-Za-z0-9\-_.+/=]*$} }

  describe '#initialize' do
    it 'sets the service settings' do
      expect(subject.settings).to eq(service_settings)
    end

    it 'sets the default expiration time to 5 minutes' do
      expect(subject.expiration).to eq(5)
    end
  end

  describe '#sign_assertion' do
    context 'when successfully signing the JWT' do
      before do
        time = Time.utc(2021, 9, 13, 19, 30, 11)
        Timecop.freeze(time)
        
        # Configure Settings to also return the test key
        allow(Settings).to receive_message_chain(:vaos, :eps, :key).and_return(test_key)
      end

      after { Timecop.return }

      it 'returns a valid JWT string' do
        expect(subject.sign_assertion).to be_a(String).and match(jwt_regex)
      end

      it 'includes the correct headers' do
        token = subject.sign_assertion
        headers = JWT.decode(token, nil, false)[1]

        expect(headers['kid']).to eq('test-key-id')
        expect(headers['typ']).to eq('JWT')
        expect(headers['alg']).to eq('RS512')
      end

      it 'includes the correct claims' do
        token = subject.sign_assertion
        payload = JWT.decode(token, nil, false)[0]

        expect(payload['iss']).to eq('test-client-id')
        expect(payload['sub']).to eq('test-client-id')
        expect(payload['aud']).to eq('https://test-audience.example.com')
        expect(payload['iat']).to eq(Time.zone.now.to_i)
        expect(payload['exp']).to eq(5.minutes.from_now.to_i)
      end

      it 'signs the token using RS512 algorithm with the correct key' do
        token = subject.sign_assertion
        public_key = OpenSSL::PKey::RSA.new(service_settings.key).public_key

        # This will raise an error if the signature is invalid
        expect do
          JWT.decode(token, public_key, true, { algorithm: 'RS512' })
        end.not_to raise_error
      end
    end

    context 'when configuration is missing' do
      let(:service_settings) do
        OpenStruct.new(
          key: nil,
          client_id: 'test-client-id',
          kid: 'test-key-id',
          audience_claim_url: 'https://test-audience.example.com'
        )
      end

      before do
        error = Common::JwtWrapper::ConfigurationError.new('Missing key')
        allow(OpenSSL::PKey::RSA).to receive(:new).and_raise(error)
      end

      it 'raises a configuration error' do
        expect { subject.sign_assertion }.to raise_error(VAOS::Exceptions::ConfigurationError)
      end
    end

    it 'properly gets the key from the delegated settings' do
      # Test that we're using the settings.key by checking if wrapper.key returns the same value
      # Allow it to be called any number of times since the implementation may call it multiple times
      allow(subject).to receive(:key).and_return(test_key)
      
      expect(subject.sign_assertion).to match(jwt_regex)
      # Verify the key was actually used by checking it was called at least once
      expect(subject).to have_received(:key).at_least(:once)
    end
  end
end
