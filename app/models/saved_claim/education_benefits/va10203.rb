# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10203 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10203')

  def after_submit(user)
    email_sent(false)
    return unless Flipper.enabled?(:edu_benefits_stem_scholarship) && FeatureFlipper.send_email?

    authorized = user.authorize(:evss, :access?)

    EducationForm::SendSCOEmail.perform_async(user.uuid, id) if authorized
  end

  def email_sent(sco_email_sent)
    application = parsed_form
    application['scoEmailSent'] = sco_email_sent
    self.form = JSON.generate(application)
    save
  end
end
