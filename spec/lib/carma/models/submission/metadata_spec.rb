# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CARMA::Models::Submission::Metadata, type: :model do
  describe '#claim_id' do
    it 'be set on init' do
      instance = described_class.new(claim_id: 100)
      expect(instance.claim_id).to eq(100)
    end
  end

  describe '::request_payload_keys' do
    it 'inherits fron Base' do
      expect(described_class.ancestors).to include(CARMA::Models::Base)
    end

    it 'sets request_payload_keys' do
      expect(described_class.request_payload_keys).to eq([:claim_id])
    end
  end

  describe '#to_request_payload' do
    it 'can receive :to_request_payload' do
      metadata = described_class.new claim_id: 123
      expect(metadata.to_request_payload).to eq(
        {
          'claimId' => 123
        }
      )
    end
  end
end
