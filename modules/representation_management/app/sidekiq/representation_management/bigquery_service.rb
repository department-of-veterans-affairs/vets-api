# frozen_string_literal: true

require 'google/cloud/bigquery'

module RepresentationManagement
  class BigqueryService
    DATASET_ID = Settings.representation_management.bigquery.dataset_id
    TABLE_ID = Settings.representation_management.bigquery.table_id

    def initialize
      authenticate
    end

    def drop_table
      table.delete
    end

    def create_table
      dataset = bigquery.dataset(DATASET_ID)

      unless dataset
        raise "Dataset not found with ID #{DATASET_ID}"
      end

      table = dataset.create_table TABLE_ID do |schema|
        schema.string 'ip_address', mode: :required
        schema.string 'representative_id', mode: :required
        schema.string 'flag_type', mode: :required
        schema.string 'flagged_value', mode: :required
        schema.timestamp 'created_at', mode: :required
        schema.timestamp 'updated_at', mode: :required
        schema.timestamp 'flagged_value_updated_at', mode: :nullable
      end
    rescue StandardError => e
      puts "Failed to create table: #{e.message}"
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
        # config.credentials = Settings.representation_management.bigquery.credentials.to_h
        config.credentials = Google::Cloud::Bigquery::Credentials.new('keyfile.json')
      end

      @bigquery = Google::Cloud::Bigquery.new
    end

    def dataset
      @dataset ||= @bigquery.dataset(DATASET_ID)
    end

    def table
      dataset.table(TABLE_ID)
    end
  end
end
