# frozen_string_literal: true

module CopayNotifications
  class ParseNewStatementsJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def self.throttle
      return Sidekiq::Limiter.unlimited if Rails.env.test?

      Sidekiq::Limiter.concurrent('new-copay-statements', 8, wait_timeout: 259_200,
                                                             lock_timeout: 120)
    end

    LIMITER = throttle

    def perform(statements_json_byte)
      # Decode and parse large json file (~60-90k objects)
      statements_json = Oj.load(Base64.decode64(statements_json_byte))
      unique_statements = statements_json.uniq { |statement| statement['veteranIdentifier'] }

      batch = Sidekiq::Batch.new

      unique_statements.each do |statement|
        LIMITER.within_limit do
          batch.jobs do
            CopayNotifications::NewStatementNotificationJob.perform_async(statement)
          end
        end
      end
    end
  end
end
