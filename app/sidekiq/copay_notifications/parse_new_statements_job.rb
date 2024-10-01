# frozen_string_literal: true

module CopayNotifications
  class ParseNewStatementsJob
    include Sidekiq::Job

    sidekiq_options retry: false

    # time (in seconds) between scheduling batch of jobs
    JOB_INTERVAL = Settings.mcp.notifications.job_interval
    # number of jobs to perform at next interval
    BATCH_SIZE = Settings.mcp.notifications.batch_size
    STATSD_KEY_PREFIX = 'api.copay_notifications.json_file'

    sidekiq_retries_exhausted do |_msg, ex|
      StatsD.increment("#{STATSD_KEY_PREFIX}.retries_exhausted")
      Rails.logger.error <<~LOG
        CopayNotifications::ParseNewStatementsJob retries exhausted:
        Exception: #{ex.class} - #{ex.message}
        Backtrace: #{ex.backtrace.join("\n")}
      LOG
    end

    def perform(statements_json_byte)
      StatsD.increment("#{STATSD_KEY_PREFIX}.total")
      # Decode and parse large json file (~60-90k objects)
      statements_json = Oj.load(Base64.decode64(statements_json_byte))
      unique_statements = statements_json.uniq { |statement| statement['veteranIdentifier'] }

      unique_statements.each_with_index do |statement, index|
        # For every BATCH_SIZE jobs, enqueue the next BATCH_SIZE amount of jobs JOB_INTERVAL seconds later
        CopayNotifications::NewStatementNotificationJob.perform_in(
          JOB_INTERVAL * (index / BATCH_SIZE), statement
        )
      end
    end
  end
end
