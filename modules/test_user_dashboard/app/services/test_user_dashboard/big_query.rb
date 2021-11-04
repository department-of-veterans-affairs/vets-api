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

    def drop(table_name:)
      table(table_name: table_name).delete
    rescue => e
      log_exception_to_sentry(e)
    end

    def create(table_name:, rows:)
      case table_name
      when TestUserDashboard::DailyMaintenance::TUD_ACCOUNTS_TABLE
        create_tud_accounts
      end

      insert_into(table_name: table_name, rows: rows)
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

    # rubocop:disable Metrics/MethodLength
    def create_tud_accounts
      table_name = TestUserDashboard::DailyMaintenance::TUD_ACCOUNTS_TABLE

      dataset.create_table table_name do |schema|
        schema.string 'account_uuid', mode: :required
        schema.string 'first_name', mode: :required
        schema.string 'middle_name'
        schema.string 'last_name', mode: :required
        schema.string 'gender', mode: :required
        schema.timestamp 'birth_date', mode: :required
        schema.integer 'ssn', mode: :required
        schema.string 'phone'
        schema.string 'email', mode: :required
        schema.timestamp 'checkout_time'
        schema.timestamp 'created_at', mode: :required
        schema.timestamp 'updated_at', mode: :required
        schema.string 'services', mode: :repeated
        schema.string 'id_type', mode: :required
        schema.string 'loa', mode: :required
        schema.string 'account_type'
        schema.string 'idme_uuid'
        schema.string 'notes'
      end
    rescue => e
      log_exception_to_sentry(e)
    end
    # rubocop:enable Metrics/MethodLength
  end
end
