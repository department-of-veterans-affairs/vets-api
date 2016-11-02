# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::DeleteOldApplications do
  before do
    @claim_nil = create(:education_benefits_claim, processed_at: nil)
    @claim_new = create(:education_benefits_claim, processed_at: Time.now.utc)
    @claim_old = create(:education_benefits_claim, processed_at: 2.months.ago)
  end

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }.to change { EducationBenefitsClaim.count }.from(3).to(2)
      expect { @claim_old.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end
  end
end
