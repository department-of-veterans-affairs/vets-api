# frozen_string_literal: true

require 'rails_helper'
require 'decision_review/utilities/saved_claim/service'

class Service < ApplicationController
  include DecisionReview::SavedClaim::Service
end

describe Service do
  describe '.store_saved_claim' do
    let(:guid) { SecureRandom.uuid }
    let(:claim_class) { SavedClaim::NoticeOfDisagreement }
    let(:form) do
      Rails.root.join('spec', 'fixtures', 'notice_of_disagreements', 'valid_NOD_create_request.json').read
    end

    context 'when an invalid claim_class is passed in' do
      it 'throws an exception' do
        expect { described_class.new.store_saved_claim(claim_class: SavedClaim, guid:, form:) }
          .to raise_error(RuntimeError, "Invalid class type 'SavedClaim'")
        expect(claim_class.find_by(guid:)).to be_nil
      end
    end

    context 'when a valid claim_class is passed in' do
      it 'saves the SavedClaim record' do
        described_class.new.store_saved_claim(claim_class:, guid:, form:)
        expect(claim_class.find_by(guid:).form).to eq form
      end
    end
  end
end
