# frozen_string_literal: true

require 'google/cloud/bigquery'

module RepresentationManagement
  class BigqueryService
    attr_reader :bigquery
    TABLE_NAME = 'flagged_veteran_representative_contact_data'

    def initialize
      authenticate
    end

    def drop_table
      table.delete
    end

    def create_table
      dataset.create_table TABLE_NAME do |schema|
        schema.string 'ip_address', mode: :required
        schema.string 'representative_id', mode: :required
        schema.string 'flag_type', mode: :required
        schema.string 'flagged_value', mode: :required
        schema.timestamp 'created_at', mode: :required
        schema.timestamp 'updated_at', mode: :required
        schema.timestamp 'flagged_value_updated_at', mode: :nullable
      end
    end

    def insert(data) # rubocop:disable Rails/Delegate
      table.insert(data) # rubocop:disable Rails/SkipsModelValidations
    end

    private

    def authenticate
      # temporary comment
      # api docs - https://cloud.google.com/ruby/docs/reference/google-cloud-bigquery/latest/AUTHENTICATION#configuration
      Google::Cloud::Bigquery.configure do |config|
        config.project_id  = Settings.representation_management.bigquery.project_id
        config.credentials = Settings.representation_management.bigquery.credentials.to_h
      end

      @bigquery = Google::Cloud::Bigquery.new
    end

    def dataset
      @dataset ||= @bigquery.dataset(Settings.representation_management.bigquery.dataset_id)
    end

    def table
      # temporary comment
      # api docs - https://cloud.google.com/ruby/docs/reference/google-cloud-bigquery/1.41.0#loading-records
      dataset.table(Settings.representation_management.bigquery.table_id)
    end
  end
end
