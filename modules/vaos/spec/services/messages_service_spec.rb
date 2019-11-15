# frozen_string_literal: true

require 'rails_helper'

describe VAOS::MessagesService do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :vaos) }
  let(:request_id) { '8a4886886e4c8e22016e5bee49c30007' }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_messages', :skip_mvi do
    it 'returns an array of size 1' do
      VCR.use_cassette('vaos/messages/get_messages', match_requests_on: %i[method uri]) do
        response = subject.get_messages(request_id)
        expect(response[:data].size).to eq(1)
      end
    end

    it 'handles unparsable JSON approprietaly' do
      VCR.use_cassette('vaos/messages/get_messages_unparsable', match_requests_on: %i[method uri]) do
        Settings.sentry.dsn = 'test' # wont actually report to sentry since we're mocking
        expect(Raven).to receive(:capture_message).with("undefined method `map' for nil:NilClass", level: 'warning')
        expect(Raven).to receive(:extra_context).with(invalid_json: {})
        response = subject.get_messages(request_id)
        Settings.sentry.dsn = nil
        expect(response[:data].size).to eq(0)
      end
    end

    it 'handles 500 errors approprietaly' do
      VCR.use_cassette('vaos/messages/get_messages_500', match_requests_on: %i[method uri]) do
        expect { subject.get_messages(request_id) }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end
  end
end
