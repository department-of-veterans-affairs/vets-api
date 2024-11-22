# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10282 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10282')

  BENEFIT_TITLE_FOR_10282 = {

}.freeze

  def after_submit(user)

  end

  private

  def send_confirmation_email(parsed_form_data, email)
    
  end
end
