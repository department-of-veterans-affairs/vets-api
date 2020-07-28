# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10203 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10203')

  def after_submit(user)
    return unless Flipper.enabled?(:edu_benefits_stem_scholarship) && FeatureFlipper.send_email?
    authorized = user.authorize(:evss, :access?)

    EducationForm::SendSCOEmail.perform_async(user.uuid, self.id) if authorized
  end
end
