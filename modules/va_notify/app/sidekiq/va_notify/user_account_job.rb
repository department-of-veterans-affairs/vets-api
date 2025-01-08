# frozen_string_literal: true

module VANotify
  class UserAccountJob
    include Sidekiq::Job
    include SentryLogging
    sidekiq_options retry: 14

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      job_class = msg['class']
      error_class = msg['error_class']
      error_message = msg['error_message']

      message = "#{job_class} retries exhausted"
      Rails.logger.error(message, { job_id:, error_class:, error_message: })
      StatsD.increment("sidekiq.jobs.#{job_class.underscore}.retries_exhausted")
    end

    def perform(
      user_account_id,
      template_id,
      personalisation = nil,
      api_key = Settings.vanotify.services.va_gov.api_key,
      callback_options = nil
    )
      user_account = UserAccount.find(user_account_id)
      notify_client = VaNotify::Service.new(api_key, callback_options)

      response = notify_client.send_email(
        {
          recipient_identifier: { id_value: user_account.icn, id_type: 'ICN' },
          template_id:, personalisation:
        }.compact
      )
      StatsD.increment('api.vanotify.user_account_job.success')
      response
    rescue VANotify::Error => e
      handle_backend_exception(e, user_account, template_id, personalisation)
    end

    def handle_backend_exception(e, user_account, template_id, personalisation)
      if e.status_code == 400
        log_exception_to_sentry(
          e,
          {
            args: { recipient_identifier: { id_value: user_account.id, id_type: 'UserAccountId' },
                    template_id:, personalisation: }
          },
          { error: :va_notify_user_account_job }
        )
      else
        raise e
      end
    end
  end
end
