# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA1995s < SavedClaim::EducationBenefits
  add_form_and_validation('22-1995S')

  def in_progress_form_id
    '22-1995'
  end
end
