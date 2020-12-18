# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10203 < SavedClaim::EducationBenefits
  add_form_and_validation('22-10203')

  def after_submit(user)
    email_sent(false)
    return unless FeatureFlipper.send_email?

    StemApplicantConfirmationMailer.build(self, nil).deliver_now

    if user.present?
      authorized = user.authorize(:evss, :access?)

      EducationForm::SendSchoolCertifyingOfficialsEmail.perform_async(user.uuid, id) if authorized
    end
  end

  def email_sent(sco_email_sent)
    update_form('scoEmailSent', sco_email_sent)
    save
  end
end
