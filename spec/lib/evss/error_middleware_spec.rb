# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'
require 'evss/auth_headers'

describe EVSS::ErrorMiddleware do
  let(:current_user) { FactoryGirl.build(:loa3_user) }
  let(:auth_headers) { EVSS::AuthHeaders.new(current_user).to_h }
  let(:claims_service) { EVSS::ClaimsService.new(auth_headers) }

  it 'should raise the proper error' do
    VCR.use_cassette('evss/claims/claim_with_errors') do
      expect { claims_service.find_claim_by_id 1 }.to raise_exception(described_class::EVSSError)
    end
  end
end
