# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10278 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10278')

  def after_submit(user)
    return unless Flipper.enabled?(:form22_10278_benefits_intake_submission)

    user_account_uuid = user&.user_account_uuid
    EducationForm::BenefitsIntake::Submit10278Job.perform_async(id, user_account_uuid)
  end

  def business_line
    'EDU'
  end
end
