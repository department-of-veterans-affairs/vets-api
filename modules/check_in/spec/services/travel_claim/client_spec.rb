# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::Client do
  subject { described_class.build(check_in: check_in) }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in) { CheckIn::V2::Session.build(data: { uuid: uuid }) }

  describe '.build' do
    it 'returns an instance of described_class' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe 'extends' do
    it 'extends forwardable' do
      expect(described_class.ancestors).to include(Forwardable)
    end
  end

  describe '#initialize' do
    it 'has settings attribute' do
      expect(subject.settings).to be_a(Config::Options)
    end

    it 'has a session' do
      expect(subject.check_in).to be_a(CheckIn::V2::Session)
    end
  end

  describe '#token' do
    context 'when veis auth service returns a success response' do
      let(:token_response) do
        {
          token_type: 'Bearer',
          expires_in: 3599,
          ext_expires_in: 3599,
          access_token: 'testtoken'
        }
      end
      let(:veis_token_response) { Faraday::Response.new(body: token_response, status: 200) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(veis_token_response)
      end

      it 'yields to block' do
        expect_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_yield(Faraday::Request.new)

        subject.token
      end

      it 'returns token' do
        expect(subject.token).to eq(veis_token_response)
      end
    end

    context 'when veis auth service returns a 401 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'invalid_client' }, status: 401) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and raises exception' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)
        expect { subject.token }.to raise_exception(exception)
      end
    end

    context 'when veis auth service returns a 500 error response' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'logs message and raises exception' do
        expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry)
        expect { subject.token }.to raise_exception(exception)
      end
    end
  end
end
