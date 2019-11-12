# frozen_string_literal: true

require 'rails_helper'

describe VAOS::MessagesService do
  let(:user) { build(:user, :vaos) }
  let(:request_id) { '8a4886886e4c8e22016e5be79a040002' }
  subject { described_class.for_user(user) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_messages', :skip_mvi do
    context 'with 10 system identifiers' do
      it 'returns an array of size 10' do
        VCR.use_cassette('vaos/messages/get_messages', record: :new_episodes) do
          response = subject.get_messages(request_id)
          expect(response.size).to eq(10)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/messages/get_messages_error', record: :new_episodes) do
          expect { subject.get_messages(request_id) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
