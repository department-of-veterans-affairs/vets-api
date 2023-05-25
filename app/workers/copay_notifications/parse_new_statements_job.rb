# frozen_string_literal: true

module CopayNotifications
  class ParseNewStatementsJob
    include Sidekiq::Worker

    sidekiq_options retry: false

    def perform(statements_json_byte)
      # Decode and parse large json file (~60-90k objects)
      statements_json = Oj.load(Base64.decode64(statements_json_byte))

      unique_statements = statements_json.uniq { |statement| statement['veteranIdentifier'] }
      unique_statements.each do |statement|
        CopayNotifications::NewStatementNotificationJob.perform_async(statement)
      end
    end
  end
end
