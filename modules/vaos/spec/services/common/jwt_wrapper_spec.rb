# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fixture_helper'

describe Common::JwtWrapper do
  subject { described_class.new(service_settings, service_config) }

  let(:service_settings) do
    OpenStruct.new(
      key: read_fixture_file('open_ssl_rsa_private.pem'),
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

  let(:rsa_private) { OpenSSL::PKey::RSA.new(read_fixture_file('open_ssl_rsa_private.pem')) }
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

      it 'signs the token using RS512 algorithm' do
        token = subject.sign_assertion
        
        # This will raise an error if the signature is invalid
        expect {
          JWT.decode(token, rsa_private.public_key, true, { algorithm: 'RS512' })
        }.not_to raise_error
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
  end
end 