# frozen_string_literal: true

require 'va_notify/service'
require 'dependents/monitor'

class Dependents::Form686c674FailureEmailJob
  include Sidekiq::Job

  FORM_ID = '686C-674'
  FORM_ID_674 = '21-674'
  STATSD_KEY_PREFIX = 'api.dependents.form_686c_674_failure_email_job'
  ZSF_DD_TAG_FUNCTION = '686c_674_failure_email_queuing'

  sidekiq_options retry: 16

  sidekiq_retries_exhausted do |msg, ex|
    claim_id = msg['args'].first
    Rails.logger.error('Form686c674FailureEmailJob exhausted all retries',
                       {
                         saved_claim_id: claim_id,
                         error_message: ex.message
                       })
    monitor = Dependents::Monitor.new(claim_id)
    monitor.log_silent_failure(monitor.default_payload.merge(message: ex.message),
                               call_location: caller_locations.first)
  end

  def perform(claim_id, email, template_id, personalisation)
    @claim = SavedClaim::DependencyClaim.find(claim_id)
    @monitor = init_monitor(claim_id)
    va_notify_client.send_email(email_address: email,
                                template_id:,
                                personalisation:)
    @monitor.log_silent_failure_avoided(@monitor.default_payload, call_location: caller_locations.first)
  rescue => e
    Rails.logger.warn('Form686c674FailureEmailJob failed, retrying send...', { claim_id:, error: e })
    raise e
  end

  private

  def va_notify_client
    @va_notify_client ||= VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key, callback_options)
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

  def init_monitor(saved_claim_id)
    @monitor ||= Dependents::Monitor.new(saved_claim_id)
  end
end
