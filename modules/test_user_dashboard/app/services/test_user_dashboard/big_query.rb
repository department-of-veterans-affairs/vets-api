# frozen_string_literal: true

require 'sentry_logging'
require 'google/cloud/bigquery'

module TestUserDashboard
  class BigQuery
    include SentryLogging

    PROJECT = 'vsp-analytics-and-insights'
    DATASET = 'vsp_testing_tools'

    attr_reader :bigquery

    def initialize
      @bigquery = Google::Cloud::Bigquery.new
    rescue => e
      log_exception_to_sentry(e)
    end

    # BigQuery requires a row indentifier in DELETE FROM statements
    def delete_from(table_name:, row_identifier: 'email')
      sql = "DELETE FROM `#{PROJECT}.#{DATASET}.#{table_name}` " \
            "WHERE #{row_identifier} IS NOT NULL"

      bigquery.query sql do |config|
        config.location = 'US'
      end
    rescue => e
      log_exception_to_sentry(e)
    end

    def insert_into(table_name:, rows:)
      # rubocop:disable Rails/SkipsModelValidations
      table(table_name: table_name).insert rows
      # rubocop:enable Rails/SkipsModelValidations
    rescue => e
      log_exception_to_sentry(e)
    end

    private

    def dataset
      bigquery.dataset DATASET, skip_lookup: true
    end

    def table(table_name:)
      dataset.table table_name, skip_lookup: true
    end
  end
end
