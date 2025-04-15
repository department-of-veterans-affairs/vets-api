# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client_session'
require_relative '../../../../../lib/common/client/concerns/mhv_jwt_session_client'

describe Common::Client::Concerns::MHVJwtSessionClient do
  before do
    allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_migrate_to_api_gateway).and_return(false)
  end

  let(:dummy_class) do
    Class.new do
      include Common::Client::Concerns::MHVJwtSessionClient

      # This will override the initialize method in the mixin
      def initialize(session: nil)
        @session = session
      end

      def session
        @session || OpenStruct.new(icn: 'ABC')
      end

      def config
        OpenStruct.new(app_token: 'sample_token')
      end

      # The following methods are wrappers around private methods, so they can be tested here.

      def test_get_jwt_from_headers(headers)
        get_jwt_from_headers(headers)
      end

      def test_decode_jwt_token(jwt_token)
        decode_jwt_token(jwt_token)
      end
    end
  end

  let(:dummy_instance) { dummy_class.new(session: session_data) }

  describe '#validate_session_params' do
    context 'when icn and app_token are present' do
      let(:session_data) { OpenStruct.new(icn: 'ABC') }

      it 'does not raise any exception' do
        expect { dummy_instance.send(:validate_session_params) }.not_to raise_error
      end
    end

    context 'when icn is missing' do
      let(:session_data) { OpenStruct.new(icn: nil) }

      it 'raises a ParameterMissing exception for user_id' do
        expect { dummy_instance.send(:validate_session_params) }
          .to raise_error(Common::Exceptions::ParameterMissing, 'Missing parameter')
      end
    end

    context 'when app_token is missing' do
      let(:session_data) { OpenStruct.new(icn: 'ABC') }

      before do
        mocked_config = OpenStruct.new(app_token: nil)
        allow(dummy_instance).to receive(:config).and_return(mocked_config)
      end

      it 'raises a ParameterMissing exception for app_token' do
        expect { dummy_instance.send(:validate_session_params) }
          .to raise_error(Common::Exceptions::ParameterMissing, 'Missing parameter')
      end
    end
  end

  describe '#get_jwt_from_headers' do
    let(:session_data) { OpenStruct.new(icn: 'ABC') }

    context 'when authorization header is properly formatted' do
      it 'returns the JWT token' do
        headers = { 'authorization' => 'Bearer sample.jwt.token' }
        token = dummy_instance.test_get_jwt_from_headers(headers)
        expect(token).to eq('sample.jwt.token')
      end
    end

    context 'when authorization header is missing' do
      it 'raises an Unauthorized exception' do
        headers = {}
        expect { dummy_instance.test_get_jwt_from_headers(headers) }
          .to raise_error(Common::Exceptions::Unauthorized)
      end
    end

    context 'when authorization header does not start with Bearer' do
      it 'raises an Unauthorized exception' do
        headers = { 'authorization' => 'sample.jwt.token' }
        expect { dummy_instance.test_get_jwt_from_headers(headers) }
          .to raise_error(Common::Exceptions::Unauthorized)
      end
    end
  end

  describe '#decode_jwt_token' do
    let(:session_data) { OpenStruct.new(icn: 'ABC') }
    let(:valid_jwt_token) { 'valid.jwt.token' }
    let(:invalid_jwt_token) { 'invalidToken' }

    context 'when token is valid' do
      before do
        allow(JWT).to receive(:decode).with(valid_jwt_token, nil, false).and_return([{ 'some' => 'data' }])
      end

      it 'decodes the JWT token successfully' do
        expect(dummy_instance.test_decode_jwt_token(valid_jwt_token)).to eq([{ 'some' => 'data' }])
      end
    end

    context 'when token is invalid' do
      before do
        allow(JWT).to receive(:decode).with(invalid_jwt_token, nil, false)
                                      .and_raise(JWT::DecodeError.new)
      end

      it 'raises an Unauthorized exception' do
        expect do
          dummy_instance.test_decode_jwt_token(invalid_jwt_token)
        end.to raise_error(Common::Exceptions::Unauthorized)
      end
    end
  end
end
