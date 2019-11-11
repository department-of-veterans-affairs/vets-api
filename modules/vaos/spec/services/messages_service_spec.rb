# frozen_string_literal: true

require 'rails_helper'

describe VAOS::MessagesService do
  let(:user) { build(:user, :vaos) }
  let(:request_id) { '1123' }
  subject { described_class.new(user, request_id) }

  # before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }
  around(:each) do |example|
    VCR.use_cassette('vaos/messages/user_session', record: :new_episodes) do
      stub_mvi(mvi_profile, icn: )
      example.run
    end
  end

  describe '#get_messages', :skip_mvi do
    context 'with 10 system identifiers' do
      it 'returns an array of size 10' do
        VCR.use_cassette('vaos/messages/get_messages', record: :new_episodes) do
          binding.pry
          response = subject.get_messages
          expect(response.size).to eq(10)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/messages/get_messages_error', record: :new_episodes) do
          expect { subject.get_messages }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
