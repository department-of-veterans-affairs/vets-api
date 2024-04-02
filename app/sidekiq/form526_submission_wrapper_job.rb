# frozen_string_literal: true

require 'evss/disability_compensation_form/service'

class Form526SubmissionWrapperJob
  include Sidekiq::Job


  sidekiq_retries_exhausted do |msg, error|
    send_failure_email
  end

  def send_failure_email
    # do da ting
  end

  def send_success_email
    # do da other ting
  end

  def perform(id)
    @submission = Form526Submission.find id
    EVSS::DisabilityCompensationForm::SubmitForm526AllClaim.perform(id)
    submit_uploads if form[FORM_526_UPLOADS].present?
    submit_form_4142 if form[FORM_4142].present?
    submit_form_0781 if form[FORM_0781].present?
    submit_form_8940 if form[FORM_8940].present?
    upload_bdd_instructions if bdd?
    submit_flashes if form[FLASHES].present?
    cleanup
    send_success_email
  end

  def submit_uploads
    # Put uploads on a one minute delay because of shared workload with EVSS
    uploads = form[FORM_526_UPLOADS]
    uploads.each do |upload|
      EVSS::DisabilityCompensationForm::SubmitUploads.perform(id, upload)
    end
  end

  def upload_bdd_instructions
    # send BDD instructions
    EVSS::DisabilityCompensationForm::UploadBddInstructions.perform(id)
  end

  def submit_form_4142
    CentralMail::SubmitForm4142Job.perform(id)
  end

  def submit_form_0781
    EVSS::DisabilityCompensationForm::SubmitForm0781.perform(id)
  end

  def submit_form_8940
    EVSS::DisabilityCompensationForm::SubmitForm8940.perform(id)
  end

  def submit_flashes
    user = User.find(@submission.user_uuid)
    # Note that the User record is cached in Redis -- `User.redis_namespace_ttl`
    # If this method runs after the TTL, then the flashes will not be applied -- a possible bug.
    BGS::FlashUpdater.perform(id) if user && Flipper.enabled?(:disability_compensation_flashes, user)
  end

  def cleanup
    EVSS::DisabilityCompensationForm::SubmitForm526Cleanup.perform(id)
  end
end
