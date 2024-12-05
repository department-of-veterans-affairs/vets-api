# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10282 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10282')

  def after_submit(user)
  end

  private

  def send_confirmation_email(parsed_form_data, email)
  end
end
