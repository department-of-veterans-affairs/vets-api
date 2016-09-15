# frozen_string_literal: true
require 'rails_helper'
require_dependency 'evss/claims_service'

describe EVSS::ClaimsService do
  let(:vaafi_headers) do
    User.sample_claimant.vaafi_headers
  end

  subject { described_class.new(vaafi_headers) }

  context 'with headers' do
    it 'should get claims' do
      VCR.use_cassette('evss/claims/claims') do
        response = subject.claims
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
