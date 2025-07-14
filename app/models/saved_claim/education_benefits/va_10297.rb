# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10297 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10297')

  def after_submit(_user)
    # Will complete later when VANotify templates are set up
  end
end
