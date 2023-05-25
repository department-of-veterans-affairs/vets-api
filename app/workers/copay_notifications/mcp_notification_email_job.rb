# frozen_string_literal: true

module CopayNotifications
  class ProfileMissingEmail < StandardError
    def initialize(vet360_id)
      @vet360_id = vet360_id
      message = "ProfileMissingEmail: Unable to derive an email address from vet360 id: #{@vet360_id}"
      super(message)
    end
  end

  class McpNotificationEmailJob
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: 14

    def perform(vet360_id, template_id, backup_email = nil, personalisation = nil)
      person_resp = VAProfile::ContactInformation::Service.get_person(vet360_id)
      email_address = person_resp.person&.emails&.first&.email_address || backup_email

      if email_address
        send_email(email_address, template_id, personalisation)
      else
        log_exception_to_sentry(CopayNotifications::ProfileMissingEmail.new(vet360_id), {},
                                { error: :mcp_notification_email_job })
      end
    rescue Common::Exceptions::BackendServiceException => e
      if e.status_code == 400
        args_hash = { args: { template_id:, personalisation: } }
        error_hash = { error: :va_notify_email_job }
        log_exception_to_sentry(e, args_hash, error_hash)
      else
        raise e
      end
    end

    def send_email(email, template_id, personalisation)
      notify_client = VaNotify::Service.new(Settings.vanotify.services.va_gov.api_key)
      notify_client.send_email(
        **{
          email_address: email,
          template_id:,
          personalisation:
        }.compact
      )
    end
  end
end
