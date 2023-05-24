# frozen_string_literal: true

# rubocop:disable Metrics/MethodLength

require 'net/http'
require 'csv'

module IncomeLimits
  class StdCountyImport
    include Sidekiq::Worker

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
            created = DateTime.strptime(row['CREATED'], '%m/%d/%Y %l:%M:%S.%N %p').to_s
            updated = DateTime.strptime(row['UPDATED'], '%m/%d/%Y %l:%M:%S.%N %p').to_s if row['UPDATED']
            std_county = StdCounty.find_or_initialize_by(id: row['ID'].to_i)
            next unless std_county.new_record?

            std_county.assign_attributes(
              name: row['NAME'].to_s,
              county_number: row['COUNTYNUMBER'].to_i,
              description: row['DESCRIPTION'],
              state_id: row['STATE_ID'].to_i,
              version: row['VERSION'].to_i,
              created:,
              updated:,
              created_by: row['CREATEDBY'].to_s,
              updated_by: row['UPDATEDBY'].to_s
            )

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
  end
end
# rubocop:enable Metrics/MethodLength
