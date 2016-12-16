# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::DeleteOldApplications do
  before do
    @claim_nil = create(:education_benefits_claim, processed_at: nil)
    @claim_new = create(:education_benefits_claim, processed_at: Time.now.utc)
    @claim_new = create(:education_benefits_claim, processed_at: 45.days.ago.utc)
    @claim_old = create(:education_benefits_claim, processed_at: 3.months.ago)
  end

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }.to change { EducationBenefitsClaim.count }.from(4).to(3)
      expect { @claim_old.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end
  end
end
