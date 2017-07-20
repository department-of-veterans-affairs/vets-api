# frozen_string_literal: true
class SavedClaim::EducationBenefits < SavedClaim
  # so it doesn't conflict with old EBC numbers
  CONFIRMATION = 'EBC2'

  # TODO require this
  has_one(:education_benefits_claim, foreign_key: 'saved_claim_id', inverse_of: :saved_claim)
end
