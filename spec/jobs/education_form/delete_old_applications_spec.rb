# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::DeleteOldApplications do
  before do
    @saved_claim_nil = create(:saved_claim)
    @edu_claim_nil = create(:education_benefits_claim, processed_at: nil, saved_claim: @saved_claim_nil)
    # @submission_nil = create(:education_benefits_submission, education_benefits_claim: @edu_claim_nil)

    @saved_claim_new = create(:saved_claim)
    @edu_claim_new = create(:education_benefits_claim, processed_at: Time.now.utc)
    # @submission_new = create(:education_benefits_submission, education_benefits_claim: @edu_claim_new)

    @saved_claim_semi_new = create(:saved_claim)
    @edu_claim_semi_new = create(:education_benefits_claim, processed_at: 45.days.ago.utc)
    # @submission_new = create(:education_benefits_submission, education_benefits_claim: @edu_claim_semi_new)

    @saved_claim_old = create(:saved_claim)
    @edu_claim_old = create(:education_benefits_claim, processed_at: 3.months.ago)
    # @submission_old = create(:education_benefits_submission, education_benefits_claim: @edu_claim_old)
  end

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }.to change { EducationBenefitsClaim.count }.from(4).to(3)
      expect { subject.perform }.to change { SavedClaim.count }.from(4).to(3)
      # expect { subject.perform }.to change { EducationBenefitsSubmission.count }.from(4).to(3)

      expect { @edu_claim_old.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      expect { @saved_claim_old.reload }.to raise_exception(ActiveRecord::RecordNotFound)

      expect { @edu_claim_new.reload }.not_to raise_exception(ActiveRecord::RecordNotFound)
      expect { @saved_claim_new.reload }.not_to raise_exception(ActiveRecord::RecordNotFound)
      expect { @edu_claim_semi_new.reload }.not_to raise_exception(ActiveRecord::RecordNotFound)
      expect { @saved_claim_semi_new.reload }.not_to raise_exception(ActiveRecord::RecordNotFound)
      expect { @edu_claim_nil.reload }.not_to raise_exception(ActiveRecord::RecordNotFound)
      expect { @saved_claim_nil.reload }.not_to raise_exception(ActiveRecord::RecordNotFound)
      # expect { @submission_old.reload }.to raise_exception(ActiveRecord::RecordNotFound)
    end

    it 'does not delete newer records' do
      expect { subject.perform }.to change { EducationBenefitsClaim.count }.from(4).to(3)
    end
  end
end
