# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client_session'
require_relative '../../../../../lib/common/client/concerns/mhv_jwt_session_client'

describe Common::Client::Concerns::MHVJwtSessionClient do
  let(:dummy_class) do
    Class.new do
      include Common::Client::Concerns::MHVJwtSessionClient

      # This will override the initialize method in the mixin
      def initialize(session: nil)
        @session = session
      end

      def session
        @session || OpenStruct.new(user_id: '123')
      end

      def config
        OpenStruct.new(app_token: 'sample_token')
      end
    end
  end

  let(:dummy_instance) { dummy_class.new(session: session_data) }

  describe '#get_session' do
    let(:session_data) { OpenStruct.new(icn: 'ABC') }
    let(:jwt_token) { 'fake.jwt.token' }
    let(:patient_fhir_id) { '12345' }
    let(:subject_id) { 'subject_id' }
    let(:decoded_token) { [{ 'subjectId' => subject_id }] }

    before do
      allow(dummy_instance).to receive(:perform_phr_refresh)
      allow(dummy_instance).to receive(:get_jwt_token).and_return(jwt_token)
      allow(dummy_instance).to receive(:get_patient_fhir_id)
      allow(dummy_instance).to receive(:save_session).and_call_original
    end

    context 'when everything is successful' do
      it 'performs PHR refresh, fetches JWT token, gets patient FHIR ID, and saves the session' do
        allow(Common::Client::Concerns::MhvSessionUtilities)
          .to receive(:decode_jwt_token).with(jwt_token).and_return(decoded_token)

        expect(dummy_instance).to receive(:perform_phr_refresh)
        expect(dummy_instance).to receive(:get_jwt_token).and_return(jwt_token)
        expect(dummy_instance).to receive(:get_patient_fhir_id).with(jwt_token)
        expect(dummy_instance).to receive(:save_session)

        expect { dummy_instance.get_session }.not_to raise_error
      end
    end

    context 'when multiple errors occur' do
      let(:error) { Common::Exceptions::Unauthorized.new }

      it 'saves a partial session and raises the first occurring exception' do
        allow(dummy_instance).to receive(:get_jwt_token).and_raise(error)
        allow(dummy_instance).to receive(:get_patient_fhir_id).and_raise(StandardError.new)
        expect(dummy_instance).to receive(:save_session)

        expect { dummy_instance.get_session }.to raise_error(Common::Exceptions::Unauthorized)
      end
    end
  end

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

  describe Common::Client::Concerns::MhvSessionUtilities do
    describe '#get_jwt_from_headers' do
      context 'when authorization header is properly formatted' do
        it 'returns the JWT token' do
          headers = { 'authorization' => 'Bearer sample.jwt.token' }
          token = described_class.get_jwt_from_headers(headers)
          expect(token).to eq('sample.jwt.token')
        end
      end

      context 'when authorization header is missing' do
        it 'raises an Unauthorized exception' do
          headers = {}
          expect { described_class.get_jwt_from_headers(headers) }
            .to raise_error(Common::Exceptions::Unauthorized)
        end
      end

      context 'when authorization header does not start with Bearer' do
        it 'raises an Unauthorized exception' do
          headers = { 'authorization' => 'sample.jwt.token' }
          expect { described_class.get_jwt_from_headers(headers) }
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
          expect(described_class.decode_jwt_token(valid_jwt_token)).to eq([{ 'some' => 'data' }])
        end
      end

      context 'when token is invalid' do
        before do
          allow(JWT).to receive(:decode).with(invalid_jwt_token, nil, false)
                                        .and_raise(JWT::DecodeError.new)
        end

        it 'raises an Unauthorized exception' do
          expect do
            described_class.decode_jwt_token(invalid_jwt_token)
          end.to raise_error(Common::Exceptions::Unauthorized)
        end
      end
    end
  end
end
