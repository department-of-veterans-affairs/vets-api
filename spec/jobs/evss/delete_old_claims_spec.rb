# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::DeleteOldClaims do
  before do
    @claim_nil = create(:evss_claim, updated_at: nil)
    @claim_new = create(:evss_claim, updated_at: Time.now.utc)
    @claim_old = create(:evss_claim, updated_at: 2.days.ago)
  end

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }.to change { EVSSClaim.count }.from(3).to(2)
      expect { @claim_old.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end
  end
end
