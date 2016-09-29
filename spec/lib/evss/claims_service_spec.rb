# frozen_string_literal: true
require 'rails_helper'
require_dependency 'evss/claims_service'

describe EVSS::ClaimsService do
  include_context 'stub mvi find_candidate response'

  let(:current_user) do
    User.sample_claimant
  end

  subject { described_class.new(current_user) }

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
