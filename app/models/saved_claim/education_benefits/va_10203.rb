# frozen_string_literal: true

class SavedClaim::EducationBenefits::VA10203 < SavedClaim::EducationBenefits
  include SentryLogging
  add_form_and_validation('22-10203')

  class Submit10203EVSSError < StandardError
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def after_submit(user)
    create_stem_automated_decision(user) if user.present?

    email_sent(false)
    return unless FeatureFlipper.send_email?

    StemApplicantConfirmationMailer.build(self, nil).deliver_now

    if user.present?
      education_benefits_claim.education_stem_automated_decision.update(confirmation_email_sent_at: Time.zone.now)
      authorized = user.authorize(:evss, :access?)

      EducationForm::SendSchoolCertifyingOfficialsEmail.perform_async(user.uuid, id) if authorized
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def create_stem_automated_decision(user)
    logger.info "EDIPI available for submit STEM claim id=#{education_benefits_claim.id}: #{user.edipi.present?}"

    education_benefits_claim.build_education_stem_automated_decision(
      user_uuid: user.uuid,
      auth_headers_json: EVSS::AuthHeaders.new(user).to_h.to_json,
      poa: get_user_poa(user)
    ).save
  end

  def email_sent(sco_email_sent)
    update_form('scoEmailSent', sco_email_sent)
    save
  end

  def get_user_poa(user)
    # stem_automated_decision feature disables EVSS call  for POA which will be removed in a future PR
    return nil if Flipper.enabled?(:stem_automated_decision, user)

    user.power_of_attorney.present? ? true : nil
  rescue => e
    log_exception_to_sentry(Submit10203EVSSError.new("Failed to retrieve VSOSearch data: #{e.message}"))
    nil
  end
end
