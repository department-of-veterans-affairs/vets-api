# frozen_string_literal: true
class SavedClaim::EducationBenefits::VA1995 < SavedClaim::EducationBenefits
  PERSISTENT_CLASS = nil
  FORM = '22-1995'

  validates(:form_id, inclusion: %w(22-1995))
end
