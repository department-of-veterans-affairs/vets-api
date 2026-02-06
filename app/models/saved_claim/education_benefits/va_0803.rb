# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA0803 < SavedClaim::EducationBenefits
  add_form_and_validation('22-0803')

  def requires_authenticated_user?
    true
  end

  def retention_period
    1.week
  end
end
