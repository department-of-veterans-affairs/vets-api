# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../app/services/common/jwt_wrapper'

describe Common::JwtWrapper do
  subject { described_class.new(settings, service_config) }

  let(:service_name) { 'TestService' }
  let(:service_config) { instance_double(VAOS::Configuration, service_name:) }
  let(:settings) do
    OpenStruct.new(
      key_path: '/path/to/key.pem',
      client_id: 'test_client',
      kid: 'test_kid',
      audience_claim_url: 'http://test.example.com/token'
    )
  end

  let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }

  before do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('/path/to/key.pem').and_return(true)
    allow(File).to receive(:read).with('/path/to/key.pem').and_return(rsa_key.to_s)
  end

  describe 'constants' do
    it 'has a SIGNING_ALGORITHM' do
      expect(described_class::SIGNING_ALGORITHM).to eq('RS512')
    end
  end

  describe '#initialize' do
    it 'sets default expiration to 5 minutes' do
      expect(subject.expiration).to eq(5)
    end

    it 'initializes settings' do
      expect(subject.settings).to eq(settings)
    end
  end

  describe '#sign_assertion' do
    let(:encoded_token) { 'encoded.jwt.token' }
    let(:test_time) { Time.zone.at(1_234_567_890) }

    before do
      # Fix the time for deterministic testing
      allow(Time.zone).to receive(:now).and_return(test_time)
      allow(JWT).to receive(:encode).and_return(encoded_token)
      allow(Rails).to receive(:logger).and_return(double('Logger').as_null_object)
      allow(OpenSSL::PKey::RSA).to receive(:new).and_return(rsa_key)
    end

    context 'when JWT encoding is successful' do
      it 'returns the encoded JWT token' do
        expect(subject.sign_assertion).to eq(encoded_token)
      end

      it 'encodes with the correct parameters' do
        # Just check that claims hash contains required keys
        expect(JWT).to receive(:encode)
          .with(
            hash_including(:iss, :sub, :aud, :iat, :exp),
            kind_of(OpenSSL::PKey::RSA),
            'RS512',
            hash_including(:kid, :typ, :alg)
          )
          .and_return(encoded_token)

        subject.sign_assertion
      end
    end

    context 'when RSA key loading fails' do
      let(:wrapper_with_error) { described_class.new(settings, service_config) }

      context 'when key file does not exist' do
        before do
          allow(File).to receive(:exist?).with('/path/to/key.pem').and_return(false)
        end

        it 'logs the error and raises a VAOS::Exceptions::ConfigurationError' do
          expect(Rails.logger).to receive(:error).with(/Service Configuration Error: RSA key file not found/)
          expect { wrapper_with_error.sign_assertion }.to raise_error(VAOS::Exceptions::ConfigurationError)
        end
      end

      context 'when key path is nil' do
        let(:settings_with_nil_path) do
          OpenStruct.new(
            key_path: nil,
            client_id: 'test_client',
            kid: 'test_kid',
            audience_claim_url: 'http://test.example.com/token'
          )
        end

        let(:wrapper_with_nil_path) { described_class.new(settings_with_nil_path, service_config) }

        it 'logs the error and raises a VAOS::Exceptions::ConfigurationError' do
          expect(Rails.logger).to receive(:error).with(/Service Configuration Error: RSA key path is not configured/)
          expect { wrapper_with_nil_path.sign_assertion }.to raise_error(VAOS::Exceptions::ConfigurationError)
        end
      end

      it 'includes the service name in the raised error' do
        allow(File).to receive(:exist?).with('/path/to/key.pem').and_return(false)

        exception = nil
        begin
          wrapper_with_error.sign_assertion
        rescue VAOS::Exceptions::ConfigurationError => e
          exception = e
        end
        expect(exception).not_to be_nil
        expect(exception.errors.first.detail).to include(service_name)
      end
    end
  end

  describe '#rsa_key' do
    it 'reads the key from the specified path' do
      expect(File).to receive(:read).with('/path/to/key.pem').once
      subject.rsa_key
    end

    it 'returns an RSA key instance' do
      allow(OpenSSL::PKey::RSA).to receive(:new).and_return(rsa_key)
      expect(subject.rsa_key).to be_a(OpenSSL::PKey::RSA)
    end

    it 'memoizes the RSA key' do
      expect(File).to receive(:read).with('/path/to/key.pem').once
      first_call = subject.rsa_key
      second_call = subject.rsa_key
      expect(first_call).to eq(second_call)
    end
  end
end
