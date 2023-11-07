# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client_session'
require_relative '../../../../../lib/common/client/concerns/mhv_fhir_session_client'

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
    end
  end

  let(:dummy_instance) { dummy_class.new(session: session_data) }

  describe '#authenticate' do
    let(:session_data) { OpenStruct.new(icn: 'ABC', expired?: false) }

    before do
      allow(dummy_instance).to receive(:invalid?).and_return(true)
      allow(dummy_instance).to receive(:lock_and_get_session).and_return(true)
      allow(dummy_class).to receive(:client_session).and_return(double('ClientSession', find_or_build: session_data))
    end

    context 'when session is valid' do
      it 'is already authenticated and simply returns self' do
        allow(dummy_instance).to receive(:invalid?).and_return(false)

        expect(dummy_instance).not_to receive(:lock_and_get_session)
        expect(dummy_instance.authenticate).to eq(dummy_instance)
      end
    end

    context 'when session is invalid' do
      it 'tries to lock and get a new session' do
        expect(dummy_instance).to receive(:lock_and_get_session).and_return(true)
        expect(dummy_instance.authenticate).to eq(dummy_instance)
      end
    end

    context 'when max iterations reached without a valid session' do
      it 'exits the loop and returns self' do
        allow(dummy_instance).to receive(:invalid?).and_return(true)

        expect(dummy_instance.authenticate).to eq(dummy_instance)
      end
    end
  end

  describe '#lock_and_get_session' do
    let(:session_data) { OpenStruct.new(icn: 'ABC', expired?: false) }

    it 'acquires a lock, gets a session, and releases the lock' do
      allow(dummy_instance).to receive(:obtain_redis_lock).and_return(true)
      allow(dummy_instance).to receive(:get_session).and_return(session_data)
      allow(dummy_instance).to receive(:release_redis_lock)

      expect(dummy_instance).to receive(:obtain_redis_lock).with('ABC').and_return(true)
      expect(dummy_instance).to receive(:get_session)
      expect(dummy_instance).to receive(:release_redis_lock).with(true, 'ABC')
      expect(dummy_instance.lock_and_get_session).to be_truthy
    end

    it 'cannot acquire a lock' do
      allow(dummy_instance).to receive(:obtain_redis_lock).and_return(false)

      expect(dummy_instance).to receive(:obtain_redis_lock).with('ABC').and_return(false)
      expect(dummy_instance).not_to receive(:get_session)
      expect(dummy_instance).not_to receive(:release_redis_lock)
      expect(dummy_instance.lock_and_get_session).to be_falsey
    end
  end

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
        expect { dummy_instance.get_session }.not_to raise_error
      end
    end

    context 'when multiple errors occur' do
      let(:error) { Common::Exceptions::Unauthorized.new }

      it 'saves a partial session and raises the first occurring exception' do
        allow(dummy_instance).to receive(:get_patient_fhir_id).and_raise(Common::Exceptions::Unauthorized)
        expect(dummy_instance).to receive(:save_session)
        expect { dummy_instance.get_session }.to raise_error(Common::Exceptions::Unauthorized)
      end
    end
  end
end
