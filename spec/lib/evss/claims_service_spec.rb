# frozen_string_literal: true
require 'rails_helper'
require_dependency 'evss/claims_service'
require_dependency 'evss/auth_headers'

describe EVSS::ClaimsService do
  let(:current_user) { FactoryGirl.create(:mvi_user) }
  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  subject { described_class.new(auth_headers) }

  context 'with headers' do
    it 'should get claims' do
      VCR.use_cassette('evss/claims/claims') do
        response = subject.all_claims
        expect(response).to be_success
      end
    end

    it 'should post create_intent_to_file' do
      VCR.use_cassette('evss/claims/create_intent_to_file') do
        response = subject.create_intent_to_file
        expect(response).to be_success
      end
    end
  end
end
