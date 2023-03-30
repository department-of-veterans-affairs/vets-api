# frozen_string_literal: true

require 'rails_helper'
require 'evss/error_middleware'

describe EVSS::ErrorMiddleware do
  let(:current_user) { FactoryBot.build(:evss_user) }
  let(:auth_headers) { EVSS::AuthHeaders.new(current_user).to_h }
  let(:transaction_id) { auth_headers['va_eauth_service_transaction_id'] }
  let(:claims_service) { EVSS::ClaimsService.new(auth_headers) }

  it 'raises the proper error', run_at: 'Wed, 13 Dec 2017 23:45:40 GMT' do
    VCR.use_cassette(
      'evss/claims/claim_with_errors',
      erb: { transaction_id: },
      match_requests_on: VCR.all_matches
    ) do
      expect { claims_service.find_claim_by_id 1 }.to raise_exception(described_class::EVSSError)
    end
  end

  it 'handles xml errors' do
    env = double
    expect(env).to receive(:[]).with(:status).and_return(200)
    expect(env).to receive(:response_headers).and_return(
      'content-type' => 'application/xml'
    )
    expect(env).to receive(:body).and_return(
      <<-XML
      <?xml version="1.0" encoding="UTF-8"?>
      <submit686Request>
        <messages>
          <severity>fatal</severity>
          <text>foo</text>
        </messages>
      </submit686Request>
      XML
    ).twice

    expect do
      described_class.new.on_complete(env)
    end.to raise_error(EVSS::ErrorMiddleware::EVSSError)
  end

  context 'with a backend service error' do
    it 'raises an evss service error', run_at: 'Wed, 13 Dec 2017 23:45:40 GMT' do
      VCR.use_cassette('evss/claims/error_504') do
        expect { claims_service.find_claim_by_id(1) }.to raise_exception(
          EVSS::ErrorMiddleware::EVSSBackendServiceError
        )
      end
    end
  end
end
