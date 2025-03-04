class Dependents::Form686c674FailureEmailJob
  include Sidekiq::Job

  FORM_ID = '686C-674'
  FORM_ID_674 = '21-674'
  STATSD_KEY_PREFIX = 'api.dependents.form_686c_674_failure_email_job'
  ZSF_DD_TAG_FUNCTION = '686c_674_failure_email_queuing'

  sidekiq_options retry: 16

  sidekiq_retries_exhausted do |msg, _ex|
    Rails.logger.error("Form686c674FailureEmailJob failed", { claim_id: msg['args'].first })
  end

  def perform(claim_id, email)
    @claim = SavedClaim::DependentsApplication.find(claim_id)
    va_notify_client.send_email(email,
                                template_id,
                                personalisation)
  end


  private

  def va_notify_client
    @va_notify_client ||= VANotify::Service.new(Settings.vanotify.services.va_gov.api_key, callback_options)
  end

  def callback_options
    {
      callback_metadata: {
        notification_type: 'error',
        form_id: @claim.form_id,
        statsd_tags: { service: 'dependent-change', function: ZSF_DD_TAG_FUNCTION }
      }
    }
  end

  def personalisation
    {
      'first_name' => @claim.parsed_form.dig('veteran_information', 'full_name', 'first')&.upcase.presence,
      'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
      'confirmation_number' => @claim.confirmation_number
    }
  end

  def template_id
    if submittable_686? && submittable_674?
      Settings.vanotify.services.va_gov.template_id.form21_686c_674_action_needed_email
    elsif submittable_686?
      Settings.vanotify.services.va_gov.template_id.form21_686c_action_needed_email
    elsif submittable_674?
      Settings.vanotify.services.va_gov.template_id.form21_674_action_needed_email
    else
      Rails.logger.error('Email template cannot be assigned for SavedClaim', saved_claim_id: id)
      nil
    end
  end
end