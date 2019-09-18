# frozen_string_literal: true

module Facilities
  class MentalHealthClient < SQL52Client
    def download
      @client.execute(select_all_mental_sql_query).to_a
    end

    private

    def select_all_mental_sql_query
      "SELECT * FROM #{mental_health_schema}.#{mental_health_table} ORDER BY #{order_by_column} ASC"
    end

    def database_name
      Settings.oit_lighthouse2.sql52.facilities_mental_health.database_name
    end

    def mental_health_table
      Settings.oit_lighthouse2.sql52.facilites_mental_health.table_name
    end

    def mental_health_schema
      Settings.oit_lighthouse2.sql52.facilites_mental_health.schema_name
    end

    def order_by_column
      'StationNumber'
    end
  end
end
