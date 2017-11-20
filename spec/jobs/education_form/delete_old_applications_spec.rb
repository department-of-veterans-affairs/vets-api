# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EducationForm::DeleteOldApplications do
  before do
    @saved_claim_nil = build(:education_benefits_1990, form: '{}')
    @saved_claim_nil.save(validate: false)
    @edu_claim_nil = create(:education_benefits_claim,
                            processed_at: nil,
                            saved_claim: @saved_claim_nil)

    @saved_claim_new = build(:education_benefits_1990, form: '{}')
    @saved_claim_new.save(validate: false)
    @edu_claim_new = create(:education_benefits_claim,
                            processed_at: Time.now.utc,
                            saved_claim: @saved_claim_new)

    @saved_claim_semi_new = build(:education_benefits_1990, form: '{}')
    @saved_claim_semi_new.save(validate: false)
    @edu_claim_semi_new = create(:education_benefits_claim,
                                 processed_at: 45.days.ago.utc,
                                 saved_claim: @saved_claim_semi_new)

    @saved_claim_old = build(:education_benefits_1990, form: '{}')
    @saved_claim_old.save(validate: false)
    @edu_claim_old = create(:education_benefits_claim,
                            processed_at: 3.months.ago,
                            saved_claim: @saved_claim_old)
  end

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }.to change { EducationBenefitsClaim.count }.from(4).to(3)
        .and change { SavedClaim::EducationBenefits.count }.from(4).to(3)

      expect { @edu_claim_old.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      expect { @saved_claim_old.reload }.to raise_exception(ActiveRecord::RecordNotFound)

      expect { @edu_claim_new.reload }.not_to raise_error
      expect { @saved_claim_new.reload }.not_to raise_error

      expect { @edu_claim_semi_new.reload }.not_to raise_error
      expect { @saved_claim_semi_new.reload }.not_to raise_error

      expect { @edu_claim_nil.reload }.not_to raise_error
      expect { @saved_claim_nil.reload }.not_to raise_error
    end
  end
end
