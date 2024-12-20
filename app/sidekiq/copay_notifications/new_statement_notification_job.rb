# frozen_string_literal: true

require 'debt_management_center/statement_identifier_service'
require 'debt_management_center/sidekiq/va_notify_email_job'

module CopayNotifications
  class Vet360IdNotFound < StandardError
    def initialize(icn)
      message = "MPIProfileMissingVet360Id: MPI Profile is missing vet360id #{icn}"
      super(message)
    end
  end

  class NewStatementNotificationJob
    include Sidekiq::Job
    include SentryLogging
    MCP_NOTIFICATION_TEMPLATE = Settings.vanotify.services.dmc.template_id.vha_new_copay_statement_email
    STATSD_KEY_PREFIX = 'api.copay_notifications.new_statement'

    sidekiq_options retry: 5

    sidekiq_retry_in do |count, exception, _jobhash|
      case exception
      when DebtManagementCenter::StatementIdentifierService::RetryableError
        10 * (count + 1)
      else
        :kill
      end
    end

    sidekiq_retries_exhausted do |_msg, ex|
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure") # remove when we get more data into the retries_exhausted below
      StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted")
      Rails.logger.error <<~LOG
        NewStatementNotificationJob retries exhausted:
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    def perform(statement)
      # rubocop:disable Lint/UselessAssignment
      StatsD.increment("#{STATSD_KEY_PREFIX}.total")
      statement_service = DebtManagementCenter::StatementIdentifierService.new(statement)
      user_data = statement_service.get_mpi_data
      icn = user_data[:icn]
      personalization = {
        'name' => user_data[:first_name],
        'date' => Time.zone.today.strftime('%B %d, %Y')
      }
      statement_date = statement['statementDate']
      account_balance = statement['accountBalance']
      Rails.logger.info("Notification Data: date-#{statement_date}, balance-#{account_balance}")
      # rubocop:enable Lint/UselessAssignment
      # pausing until further notice
      # DebtManagementCenter::VANotifyEmailJob.perform_async(icn, MCP_NOTIFICATION_TEMPLATE, personalization, 'icn')
    end
  end
end
