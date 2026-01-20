# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client_session'
require_relative '../../../../../lib/common/client/concerns/mhv_jwt_session_client'

describe Common::Client::Concerns::MHVJwtSessionClient do
  let(:dummy_class) do
    Class.new do
      include Common::Client::Concerns::MHVJwtSessionClient

      attr_reader :session
      attr_reader :icn

      # This will override the initialize method in the mixin
      def initialize(session:, icn: nil)
        @session = session
        @icn = icn
      end

      def config
        OpenStruct.new(app_token: 'sample_token')
      end
    end
  end

  let(:session_data) { OpenStruct.new(user_uuid: '12345') }
  let(:icn_value) { 'ABC' }
  let(:dummy_instance) { dummy_class.new(session: session_data, icn: icn_value) }

  describe '#user_key' do
    it 'returns the user UUID' do
      user_key = dummy_instance.send(:user_key)
      expect(user_key).to eq('12345')
    end
  end

  describe '#validate_session_params' do
    context 'when icn and app_token are present' do
      it 'does not raise any exception' do
        expect { dummy_instance.send(:validate_session_params) }.not_to raise_error
      end
    end

    context 'when icn is missing' do
      let(:icn_value) { nil }

      it 'raises a ParameterMissing exception for user_id' do
        expect { dummy_instance.send(:validate_session_params) }
          .to raise_error(Common::Exceptions::ParameterMissing, 'Missing parameter')
      end
    end

    context 'when app_token is missing' do
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
    context 'when authorization header is properly formatted' do
      it 'returns the JWT token' do
        headers = { 'x-amzn-remapped-authorization' => 'Bearer sample.jwt.token' }
        token = dummy_instance.send(:get_jwt_from_headers, headers)
        expect(token).to eq('sample.jwt.token')
      end
    end

    context 'when authorization header is missing' do
      it 'raises an Unauthorized exception' do
        headers = {}
        expect { dummy_instance.send(:get_jwt_from_headers, headers) }
          .to raise_error(Common::Exceptions::Unauthorized)
      end
    end

    context 'when authorization header does not start with Bearer' do
      it 'raises an Unauthorized exception' do
        headers = { 'authorization' => 'sample.jwt.token' }
        expect { dummy_instance.send(:get_jwt_from_headers, headers) }
          .to raise_error(Common::Exceptions::Unauthorized)
      end
    end
  end

  describe '#decode_jwt_token' do
    let(:valid_jwt_token) { 'valid.jwt.token' }
    let(:invalid_jwt_token) { 'invalidToken' }

    context 'when token is valid' do
      before do
        allow(JWT).to receive(:decode).with(valid_jwt_token, nil, false).and_return([{ 'some' => 'data' }])
      end

      it 'decodes the JWT token successfully' do
        expect(dummy_instance.send(:decode_jwt_token, valid_jwt_token)).to eq([{ 'some' => 'data' }])
      end
    end

    context 'when token is invalid' do
      before do
        allow(JWT).to receive(:decode).with(invalid_jwt_token, nil, false).and_raise(JWT::DecodeError.new)
      end

      it 'raises an Unauthorized exception' do
        expect { dummy_instance.send(:decode_jwt_token, invalid_jwt_token) }
          .to raise_error(Common::Exceptions::Unauthorized)
      end
    end
  end
end
