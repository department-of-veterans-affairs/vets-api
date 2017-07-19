# frozen_string_literal: true
class SavedClaim::EducationBenefits < SavedClaim
  # 1990E 5490 5495 1990N
  CONFIRMATION = 'EBC'

  has_one(:education_benefits_claim, foreign_key: 'saved_claim_id', inverse_of: :saved_claim)
end
