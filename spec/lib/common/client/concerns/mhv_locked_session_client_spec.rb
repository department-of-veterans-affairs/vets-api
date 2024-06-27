# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client_session'
require_relative '../../../../../lib/common/client/concerns/mhv_locked_session_client'

describe Common::Client::Concerns::MhvLockedSessionClient do
  let(:dummy_class) do
    Class.new do
      include Common::Client::Concerns::MhvLockedSessionClient

      # This will override the initialize method in the mixin
      def initialize(session: nil)
        @session = session
      end

      def user_key
        session.icn
      end

      def get_session; end

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
      allow(dummy_instance).to receive_messages(invalid?: true, lock_and_get_session: true)
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
        stub_const('Common::Client::Concerns::MhvLockedSessionClient::LOCK_RETRY_DELAY', 0)
        allow(dummy_instance).to receive_messages(invalid?: true, lock_and_get_session: false)

        expect(dummy_instance).to receive(:lock_and_get_session)
          .exactly(Common::Client::Concerns::MhvLockedSessionClient::RETRY_ATTEMPTS).times
        expect(dummy_instance.authenticate).to eq(dummy_instance)
      end
    end
  end

  describe '#lock_and_get_session' do
    let(:session_data) { OpenStruct.new(icn: 'ABC', expired?: false) }

    it 'acquires a lock, gets a session, and releases the lock' do
      allow(dummy_instance).to receive_messages(obtain_redis_lock: true, get_session: session_data)
      allow(dummy_instance).to receive(:release_redis_lock)

      expect(dummy_instance).to receive(:obtain_redis_lock).and_return(true)
      expect(dummy_instance).to receive(:get_session)
      expect(dummy_instance).to receive(:release_redis_lock).with(true)
      expect(dummy_instance.send(:lock_and_get_session)).to be_truthy
    end

    it 'cannot acquire a lock' do
      allow(dummy_instance).to receive(:obtain_redis_lock).and_return(false)

      expect(dummy_instance).to receive(:obtain_redis_lock).and_return(false)
      expect(dummy_instance).not_to receive(:get_session)
      expect(dummy_instance).not_to receive(:release_redis_lock)
      expect(dummy_instance.send(:lock_and_get_session)).to be_falsey
    end
  end
end
