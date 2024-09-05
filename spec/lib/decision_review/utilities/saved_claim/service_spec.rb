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

    context 'when an invalid class is passed in' do
      before do
        Flipper.enable :decision_review_form_store_saved_claims
      end

      it 'handles the exception' do
        expect { described_class.new.store_saved_claim(claim_class: SavedClaim, guid:, form:) }.not_to raise_error
        expect(claim_class.find_by(guid:)).to be_nil
      end
    end

    context 'when flipper is enabled' do
      before do
        Flipper.enable :decision_review_form_store_saved_claims
      end

      it 'saves the SavedClaim record' do
        described_class.new.store_saved_claim(claim_class:, guid:, form:)
        expect(claim_class.find_by(guid:).form).to eq form
      end
    end

    context 'when flipper is disabled' do
      before do
        Flipper.disable :decision_review_form_store_saved_claims
      end

      it 'does not save the SavedClaim record' do
        described_class.new.store_saved_claim(claim_class:, guid:, form:)
        expect(claim_class.find_by(guid:)).to be_nil
      end
    end
  end
end
