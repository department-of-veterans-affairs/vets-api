# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fixture_helper'

describe Common::JwtWrapper do
  subject { described_class.new(service_settings, service_config) }

  # Generate a test RSA key
  let(:test_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:test_key_path) { '/path/to/test/key.pem' }

  let(:service_settings) do
    OpenStruct.new(
      key_path: test_key_path,
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

  # JWT REGEX has 3 base64 url encoded parts (header, payload signature)
  let(:jwt_regex) { %r{^[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.?[A-Za-z0-9\-_.+/=]*$} }

  describe '#initialize' do
    it 'sets the default expiration time to 5 minutes' do
      expect(subject.expiration).to eq(5)
    end
  end

  describe '#sign_assertion' do
    context 'when successfully signing the JWT' do
      before do
        time = Time.utc(2021, 9, 13, 19, 30, 11)
        Timecop.freeze(time)

        # Mock File.read to return the test key
        allow(File).to receive(:read).with(test_key_path).and_return(test_key.to_s)
      end

      after { Timecop.return }

      it 'returns a valid JWT token and verifies its contents' do
        token = subject.sign_assertion

        # Check that it's a valid JWT
        expect(token).to match(jwt_regex)

        # Decode and verify the token
        decoded_token = JWT.decode(
          token,
          test_key.public_key,
          true,
          { algorithm: 'RS512' }
        )

        # Verify payload
        payload = decoded_token[0]
        expect(payload['iss']).to eq('test-client-id')
        expect(payload['sub']).to eq('test-client-id')
        expect(payload['aud']).to eq('https://test-audience.example.com')
        expect(payload['iat']).to eq(Time.zone.now.to_i)
        expect(payload['exp']).to eq(5.minutes.from_now.to_i)

        # Verify headers
        headers = decoded_token[1]
        expect(headers['kid']).to eq('test-key-id')
        expect(headers['typ']).to eq('JWT')
        expect(headers['alg']).to eq('RS512')
      end
    end

    context 'when key file cannot be found' do
      before do
        allow(File).to receive(:read).with(test_key_path).and_raise(Errno::ENOENT.new('File not found'))
      end

      it 'raises a configuration error' do
        expect { subject.sign_assertion }.to raise_error(VAOS::Exceptions::ConfigurationError)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Key file not found/)
        expect { subject.sign_assertion }.to raise_error(VAOS::Exceptions::ConfigurationError)
      end
    end

    context 'when configuration is invalid' do
      before do
        allow(File).to receive(:read).with(test_key_path).and_return(test_key.to_s)
        error = Common::JwtWrapper::ConfigurationError.new('Invalid configuration')
        allow(JWT).to receive(:encode).and_raise(error)
      end

      it 'raises a configuration error' do
        expect { subject.sign_assertion }.to raise_error(VAOS::Exceptions::ConfigurationError)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Service Configuration Error/)
        expect { subject.sign_assertion }.to raise_error(VAOS::Exceptions::ConfigurationError)
      end
    end
  end
end
