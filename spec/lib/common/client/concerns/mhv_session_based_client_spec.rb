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
    let(:session_data) { OpenStruct.new(user_uuid: '12345', user_id: '00000', icn: 'ABC') }

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_uuid_for_mhv_session_locking).and_return(true)
      end

      it 'returns the user UUID' do
        user_key = dummy_instance.send(:user_key)
        expect(user_key).to eq('12345')
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_uuid_for_mhv_session_locking).and_return(false)
      end

      it 'returns the user ID (MHV correlation ID)' do
        user_key = dummy_instance.send(:user_key)
        expect(user_key).to eq('00000')
      end
    end
  end
end
