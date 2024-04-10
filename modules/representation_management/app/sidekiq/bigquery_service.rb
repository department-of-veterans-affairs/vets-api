# frozen_string_literal: true

require 'google/cloud/bigquery'

module RepresentationManagement
  class BigqueryService
    TABLE_NAME = 'my_table'

    def initialize
      authenticate
    end

    def drop_table
      table.delete
    end

    def create_table
      # temporary comment
      # update schema
      dataset.create_table TABLE_NAME do |schema|
        schema.string 'first_name', mode: :required
        schema.record 'cities_lived', mode: :repeated do |nested_schema|
          nested_schema.string 'place', mode: :required
          nested_schema.integer 'number_of_years', mode: :required
        end
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
        config.credentials = Settings.representation_management.bigquery.credentials
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
