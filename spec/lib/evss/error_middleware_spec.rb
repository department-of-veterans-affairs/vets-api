# frozen_string_literal: true

require 'rails_helper'
require 'evss/claims_service'
require 'evss/auth_headers'

describe EVSS::ErrorMiddleware do
  let(:current_user) { FactoryBot.build(:evss_user) }
  let(:auth_headers) { EVSS::AuthHeaders.new(current_user).to_h }
  let(:claims_service) { EVSS::ClaimsService.new(auth_headers) }

  it 'should raise the proper error', run_at: 'Wed, 13 Dec 2017 23:45:40 GMT' do
    VCR.use_cassette('evss/claims/claim_with_errors', VCR::MATCH_EVERYTHING) do
      expect { claims_service.find_claim_by_id 1 }.to raise_exception(described_class::EVSSError)
    end
  end

  context 'with a backend service error' do
    it 'should raise an evss service error', run_at: 'Wed, 13 Dec 2017 23:45:40 GMT' do
      VCR.use_cassette('evss/claims/error_504') do
        expect { claims_service.find_claim_by_id(1) }.to raise_exception(described_class::EVSSBackendServiceError)
      end
    end
  end
end
