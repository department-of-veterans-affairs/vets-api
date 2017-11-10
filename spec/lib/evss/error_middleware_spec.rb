# frozen_string_literal: true
require 'rails_helper'
require 'evss/auth_headers'

describe EVSS::ErrorMiddleware do
  let(:current_user) { FactoryGirl.build(:user, :loa3) }
  let(:claims_service) { EVSS::Claims::Service.new(current_user) }

  it 'should raise the proper error' do
    VCR.use_cassette('evss/claims/claim_with_errors') do
      expect { claims_service.find_claim_by_id 1 }.to raise_exception(described_class::EVSSError)
    end
  end
end
