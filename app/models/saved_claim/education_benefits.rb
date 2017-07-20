# frozen_string_literal: true
class SavedClaim::EducationBenefits < SavedClaim
  CONFIRMATION = 'EBC'

  # TODO require this
  has_one(:education_benefits_claim, foreign_key: 'saved_claim_id', inverse_of: :saved_claim)
end
