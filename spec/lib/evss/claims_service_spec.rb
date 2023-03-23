# frozen_string_literal: true

require 'rails_helper'
require 'evss/claims_service'

describe EVSS::ClaimsService do
  subject { claims_service }

  let(:current_user) do
    create(:evss_user)
  end

  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  let(:claims_service) { described_class.new(auth_headers) }

  let(:transaction_id) { auth_headers['va_eauth_service_transaction_id'] }

  context 'with headers' do
    let(:evss_id) { 189_625 }

    it 'gets claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      VCR.use_cassette(
        'evss/claims/claims',
        erb: { transaction_id: },
        match_requests_on: VCR.all_matches
      ) do
        response = subject.all_claims
        expect(response).to be_success
      end
    end

    it 'gets a claim with docs' do
      VCR.use_cassette('evss/claims/claim_with_docs') do
        response = subject.find_claim_with_docs_by_id('600117255')
        expect(response).to be_success
      end
    end

    it 'posts a 5103 waiver', run_at: 'Tue, 12 Dec 2017 03:21:11 GMT' do
      VCR.use_cassette(
        'evss/claims/set_5103_waiver',
        erb: { transaction_id: },
        match_requests_on: VCR.all_matches
      ) do
        response = subject.request_decision(evss_id)
        expect(response).to be_success
      end
    end

    context 'with a backend service error' do
      it 'raises EVSSError' do
        VCR.use_cassette('evss/claims/claims_with_errors') do
          expect { subject.all_claims }.to raise_exception(EVSS::ErrorMiddleware::EVSSError)
        end
      end
    end
  end
end
