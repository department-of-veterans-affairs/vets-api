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
      icn = statement_service.get_icn
      DebtManagementCenter::VANotifyEmailJob.perform_async(icn, MCP_NOTIFICATION_TEMPLATE, nil, 'icn')
    end
  end
end
