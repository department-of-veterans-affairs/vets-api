# frozen_string_literal: true

require 'sentry_logging'
require 'google/cloud/bigquery'

module TestUserDashboard
  class BigQuery
    include SentryLogging

    DATASET = 'vsp_testing_tools'

    attr_reader :bigquery

    def initialize
      @bigquery = Google::Cloud::Bigquery.new
    rescue => e
      log_exception_to_sentry(e)
    end

    def insert_into(table:, rows:)
      dataset = bigquery.dataset DATASET, skip_lookup: true
      table = dataset.table table, skip_lookup: true

      # rubocop:disable Rails/SkipsModelValidations
      table.insert rows
      # rubocop:enable Rails/SkipsModelValidations
    rescue => e
      log_exception_to_sentry(e)
    end
  end
end
