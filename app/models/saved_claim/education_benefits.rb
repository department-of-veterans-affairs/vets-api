# frozen_string_literal: true
class SavedClaim::EducationBenefits < SavedClaim
  # CONFIRMATION = 'BUR'

  has_one(:education_benefits_claim, inverse_of: :saved_claim)
end
