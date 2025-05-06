# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Pensions::ZeroSilentFailures::ManualRemediation do
  let(:fake_claim) { build(:pensions_saved_claim) }

  context 'method override coverage' do
    it 'uses expected claim class' do
      expect(Pensions::SavedClaim).to receive(:find).with(fake_claim.id)
      described_class.new(fake_claim.id)
    end

    it 'returns expected stamps' do
      allow(Pensions::SavedClaim).to receive(:find).and_return(fake_claim)
      remediation = described_class.new(fake_claim.id)

      timestamp = Time.zone.now
      stamps = remediation.send('stamps', timestamp)

      expect(stamps.length).to equal(2)
      # base
      expect(stamps.first[:x]).to equal(5)
      expect(stamps.first[:y]).to equal(5)
      expect(stamps.first[:timestamp]).to equal(timestamp)
      # pensions
      expect(stamps.second[:x]).to equal(429)
      expect(stamps.second[:y]).to equal(770)
      expect(stamps.second[:timestamp]).to equal(timestamp)
    end

    it 'returns additional metadata fields' do
      allow(Pensions::SavedClaim).to receive(:find).and_return(fake_claim)
      remediation = described_class.new(fake_claim.id)

      metadata = remediation.send('generate_metadata')
      expected = hash_including(lighthouseBenefitIntakeSubmissionUUID: anything,
                                lighthouseBenefitIntakeSubmissionDate: anything)

      expect(metadata).to match(expected)
    end
  end
end
