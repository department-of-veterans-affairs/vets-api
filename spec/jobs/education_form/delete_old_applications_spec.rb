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

    @saved_claim10203_old = build(:education_benefits_10203, form: '{}')
    @saved_claim10203_old.save(validate: false)
    @edu_claim10203_old = create(:education_benefits_claim_10203,
                                 education_stem_automated_decision: build(:education_stem_automated_decision),
                                 processed_at: 13.months.ago,
                                 saved_claim: @saved_claim10203_old)

    @saved_claim10203_newer = build(:education_benefits_10203, form: '{}')
    @saved_claim10203_newer.save(validate: false)
    @edu_claim10203_newer = create(:education_benefits_claim_10203,
                                   education_stem_automated_decision: build(:education_stem_automated_decision),
                                   processed_at: 11.months.ago,
                                   saved_claim: @saved_claim10203_newer)
  end

  describe '#perform' do
    it 'deletes old records' do
      expect { subject.perform }
        .to change(EducationBenefitsClaim, :count).from(6).to(4)
        .and change { SavedClaim::EducationBenefits.count }
        .from(6).to(4)
        .and change(EducationStemAutomatedDecision, :count)
        .from(2).to(1)
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
