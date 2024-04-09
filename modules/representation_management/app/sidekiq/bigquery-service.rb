# frozen-string-literal: true

require "google/cloud/bigquery"

module RepresentationManagement
  class BigqueryService
    def initialize
      authenticate
    end

    def insert(data)
      table.insert(data)
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

    def table
      # temporary comment
      # api docs - https://cloud.google.com/ruby/docs/reference/google-cloud-bigquery/1.41.0#loading-records
      dataset = @bigquery.dataset(Settings.representation_management.bigquery.dataset_id)
      dataset.table(Settings.representation_management.bigquery.table_id)
    end
  end
end