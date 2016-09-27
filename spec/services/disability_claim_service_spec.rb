# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimService do
  let(:user) { User.sample_claimant }
  let(:claim) do
    FactoryGirl.create(:disability_claim, data: { participant_id: user.participant_id })
  end
  let(:client_stub) { instance_double('EVSS::ClaimsService') }
  subject { described_class.new(user) }

  context 'when EVSS client times out' do
    describe '#all' do
      it 'returns all claims for the user' do
        allow(client_stub).to receive(:all_claims) { raise Faraday::Error::TimeoutError }
        allow(subject).to receive(:client) { client_stub }
        expect(subject.all).to eq([claim])
      end
    end

    describe '#find_by_evss_id' do
      it 'returns claim' do
        allow(client_stub).to receive(:find_claim_by_id) { raise Faraday::Error::TimeoutError }
        allow(subject).to receive(:client) { client_stub }
        expect(subject.find_by_evss_id(claim.evss_id)).to eq(claim)
      end
    end
  end
end
