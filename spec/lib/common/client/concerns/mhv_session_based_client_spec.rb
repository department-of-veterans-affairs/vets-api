# frozen_string_literal: true

require 'rails_helper'
require 'medical_records/client_session'
require_relative '../../../../../lib/common/client/concerns/mhv_session_based_client'

describe Common::Client::Concerns::MHVSessionBasedClient do
  let(:dummy_class) do
    Class.new do
      include Common::Client::Concerns::MHVSessionBasedClient

      # This will override the initialize method in the mixin
      def initialize(session: nil)
        @session = session
      end
    end
  end

  let(:dummy_instance) { dummy_class.new(session: session_data) }

  describe '#user_key' do
    let(:session_data) { OpenStruct.new(user_id: 12_345, icn: 'ABC') }

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_hash_id_for_mhv_session_locking).and_return(true)
      end

      it 'returns a hashed user_id' do
        expected_digest = Digest::SHA256.hexdigest(12_345.to_s)

        user_key = dummy_instance.send(:user_key)
        expect(user_key).to eq(expected_digest)
        expect(user_key.length).to eq(64) # sanity check: SHA256 hex digest length
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_hash_id_for_mhv_session_locking).and_return(false)
      end

      it 'returns the raw user_id' do
        user_key = dummy_instance.send(:user_key)
        expect(user_key).to eq(12_345)
      end
    end
  end
end
