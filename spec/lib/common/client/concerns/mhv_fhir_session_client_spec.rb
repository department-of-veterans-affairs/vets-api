# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client_session'
require 'common/client/concerns/mhv_fhir_session_client'

describe Common::Client::Concerns::MhvFhirSessionClient do
  let(:dummy_class) do
    Class.new do
      include Common::Client::Concerns::MhvFhirSessionClient

      # This will override the initialize method in the mixin
      def initialize(session: nil)
        @session = session
      end

      def session
        @session || OpenStruct.new(user_id: '123')
      end

      def config
        OpenStruct.new(app_token: 'sample_token', base_request_headers: {})
      end

      # This wrapper is necessary for testing as get_session is protected.
      def test_get_session
        get_session
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
      allow_any_instance_of(Common::Client::Concerns::MHVJwtSessionClient)
        .to receive(:get_session).and_return(OpenStruct.new(
                                               token: jwt_token, expires_at: Date.new.rfc2822
                                             ))
      allow(dummy_instance).to receive(:perform_phr_refresh)
      allow(dummy_instance).to receive(:get_patient_fhir_id)
      allow(dummy_instance).to receive(:save_session).and_call_original
    end

    context 'when everything is successful' do
      it 'performs PHR refresh, fetches JWT token, gets patient FHIR ID, and saves the session' do
        expect(dummy_instance).to receive(:perform_phr_refresh)
        expect(dummy_instance).to receive(:get_patient_fhir_id).with(jwt_token)
        expect(dummy_instance).to receive(:save_session)
        expect { dummy_instance.test_get_session }.not_to raise_error
      end
    end

    context 'when multiple errors occur' do
      let(:error) { Common::Exceptions::Unauthorized.new }

      it 'saves a partial session and raises the first occurring exception' do
        allow(dummy_instance).to receive(:get_patient_fhir_id).and_raise(Common::Exceptions::Unauthorized)
        expect(dummy_instance).to receive(:save_session)
        expect { dummy_instance.test_get_session }.to raise_error(Common::Exceptions::Unauthorized)
      end
    end
  end
end
