# frozen_string_literal: true
class SavedClaim::EducationBenefits < SavedClaim
  CONFIRMATION = 'EBC'

  has_one(:education_benefits_claim, foreign_key: 'saved_claim_id', inverse_of: :saved_claim)

  validates(:form_id, inclusion: %w(1990 1995 1990E 5490 5495 1990N).map { |c| "22-#{c}" })
end
