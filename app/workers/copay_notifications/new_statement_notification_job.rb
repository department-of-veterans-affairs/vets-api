# frozen_string_literal: true

require 'debt_management_center/statement_identifier_service'
require 'debt_management_center/workers/va_notify_email_job'

module CopayNotifications
  class Vet360IdNotFound < StandardError
    def initialize(icn)
      message = "MPIProfileMissingVet360Id: MPI Profile is missing vet360id #{icn}"
      super(message)
    end
  end

  class NewStatementNotificationJob
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_options retry: 5

    sidekiq_retry_in do |count, exception, _jobhash|
      case exception
      when DebtManagementCenter::StatementIdentifierService::RetryableError
        10 * (count + 1)
      else
        :kill
      end
    end

    MCP_NOTIFICATION_TEMPLATE = Settings.vanotify.services.dmc.template_id.vha_new_copay_statement_email
    STATSD_KEY_PREFIX = 'api.copay_notifications.new_statement'

    def perform(statement)
      StatsD.increment("#{STATSD_KEY_PREFIX}.total")
      statement_service = DebtManagementCenter::StatementIdentifierService.new(statement)
      email_address = statement_service.derive_email_address
      DebtManagementCenter::VANotifyEmailJob.perform_async(email_address, MCP_NOTIFICATION_TEMPLATE)
    rescue DebtManagementCenter::StatementIdentifierService::UnableToSourceEmailForStatement => e
      log_exception_to_sentry(e, {}, { info: :unable_to_source_email_for_statement }, 'info')
    end
  end
end
