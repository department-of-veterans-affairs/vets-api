# frozen_string_literal: true

require 'rails_helper'

describe VAOS::MessagesService do
  let(:user) { build(:user, :vaos) }
  let(:request_id) { '8a4886886e4c8e22016e5bee49c30007' }
  subject { described_class.for_user(user) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_messages', :skip_mvi do
    context 'with 10 system identifiers' do
      it 'returns an array of size 10' do
        VCR.use_cassette('vaos/messages/get_messages', match_requests_on: %i[host path method]) do
          response = subject.get_messages(request_id)
          expect(response.size).to eq(2)
        end
      end
    end
  end
end
