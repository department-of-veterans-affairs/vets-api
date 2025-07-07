# frozen_string_literal: true

require 'rails_helper'
require_relative '../rails_helper'

describe ClaimsApi::EVSSService::Base do
  let(:claim) { double('claim', auth_headers: {}, id: '123', transaction_id: 'abc-123') }
  let(:evss_service) { described_class.new }
  let(:faraday_response) { double('faraday_response') }

  before do
    allow(evss_service).to receive(:access_token).and_return('some-token')
  end

  describe '#submit' do
    context 'when the upstream service returns a string' do
      before do
        allow(faraday_response).to receive(:body).and_return('a string error from upstream')
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_return(faraday_response)
      end

      it 'does not raise an error' do
        expect { evss_service.submit(claim, {}) }.not_to raise_error
      end
    end

    context 'when the upstream service returns an error' do
      let(:error) { Common::Client::Errors::ClientError.new('Upstream error') }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(error)
      end

      it 'handles the error' do
        custom_error_double = double('ClaimsApi::CustomError')
        allow(ClaimsApi::CustomError).to receive(:new).and_return(custom_error_double)
        allow(custom_error_double).to receive(:build_error)

        evss_service.submit(claim, {})

        expect(ClaimsApi::CustomError).to have_received(:new).with(error, 'Upstream error', true)
        expect(custom_error_double).to have_received(:build_error)
      end
    end
  end
end
