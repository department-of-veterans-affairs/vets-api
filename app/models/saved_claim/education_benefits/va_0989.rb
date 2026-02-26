# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA0989 < SavedClaim::EducationBenefits
  add_form_and_validation('22-0989')

  def requires_authenticated_user?
    true
  end

  def retention_period
    60.days
  end
end
