# frozen_string_literal: true

require 'vets/shared_logging'

###########################################################################################
# This class is deprecated in favor of modules/va_notify/app/sidekiq/va_notify/email_job.rb
# Use that one instead.
###########################################################################################
# TODO: Remove this class
class VANotifyEmailJob
  include Sidekiq::Job
  include Vets::SharedLogging
  # retry for  2d 1h 47m 12s
  # https://github.com/sidekiq/sidekiq/wiki/Error-Handling
  sidekiq_options retry: 16

  def perform(email, template_id, personalisation = nil)
    notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)

    notify_client.send_email(
      **{
        email_address: email,
        template_id:,
        personalisation:
      }.compact
    )
  rescue VANotify::Error => e
    if e.status_code == 400
      log_exception_to_sentry(
        e,
        { args: { template_id:, personalisation: } },
        { error: :va_notify_email_job }
      )
      log_exception_to_rails(e)
    else
      raise e
    end
  end
end
