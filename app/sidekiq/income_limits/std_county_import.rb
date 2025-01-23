# frozen_string_literal: true

require 'net/http'
require 'csv'

module IncomeLimits
  class StdCountyImport
    include Sidekiq::Job

    def fetch_csv_data
      csv_url = 'https://sitewide-public-websites-income-limits-data.s3-us-gov-west-1.amazonaws.com/std_county.csv'
      uri = URI(csv_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      response.body if response.code == '200'
    end

    def perform
      ActiveRecord::Base.transaction do
        data = fetch_csv_data
        if data
          CSV.parse(data, headers: true) do |row|
            std_county = StdCounty.find_or_initialize_by(id: row['ID'].to_i)
            next unless std_county.new_record?

            std_county.assign_attributes(std_county_attributes(row))
            std_county.save!
          end
        else
          raise 'Failed to fetch CSV data.'
        end
      end
    rescue => e
      ActiveRecord::Base.rollback_transaction
      raise "error: #{e}"
    end

    private

    def std_county_attributes(row)
      {
        name: row['NAME'].to_s,
        county_number: row['COUNTYNUMBER'].to_i,
        description: row['DESCRIPTION'],
        state_id: row['STATE_ID'].to_i,
        version: row['VERSION'].to_i,
        created: date_formatter(row['CREATED']),
        updated: date_formatter(row['UPDATED']),
        created_by: row['CREATEDBY'].to_s,
        updated_by: row['UPDATEDBY'].to_s
      }
    end

    def date_formatter(date)
      return nil unless date

      DateTime.strptime(date, '%F %H:%M:%S %z').to_s
    end
  end
end
