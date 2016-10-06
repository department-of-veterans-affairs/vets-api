# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimService do
  let(:user) { User.sample_claimant }
  let(:client_stub) { instance_double('EVSS::ClaimsService') }
  subject { described_class.new(user) }

  context 'when EVSS client times out' do
    describe '#all' do
      it 'returns all claims for the user' do
        allow(client_stub).to receive(:all_claims) { raise Faraday::Error::TimeoutError }
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryGirl.create(:disability_claim, user_uuid: user.uuid)
        claims = subject.all
        expect(claims).to eq([claim])
        expect(claims.first.successful_sync).to eq(false)
      end
    end

    describe '#update_from_remote' do
      it 'returns claim' do
        allow(client_stub).to receive(:find_claim_by_id) { raise Faraday::Error::TimeoutError }
        allow(subject).to receive(:client) { client_stub }
        claim = FactoryGirl.build(:disability_claim, user_uuid: user.uuid)
        updated_claim = subject.update_from_remote(claim)
        expect(updated_claim).to eq(claim)
        expect(updated_claim.successful_sync).to eq(false)
      end
    end
  end
end
