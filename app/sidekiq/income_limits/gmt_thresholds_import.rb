# frozen_string_literal: true

require 'net/http'
require 'csv'

module IncomeLimits
  class GmtThresholdsImport
    include Sidekiq::Job

    def fetch_csv_data
      csv_url = 'https://sitewide-public-websites-income-limits-data.s3-us-gov-west-1.amazonaws.com/std_gmtthresholds.csv'
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
            gmt_threshold = GmtThreshold.find_or_initialize_by(id: row['ID'].to_i)
            next unless gmt_threshold.new_record?

            gmt_threshold.assign_attributes(gmt_threshold_attributes(row))
            gmt_threshold.save!
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

    def gmt_threshold_attributes(row)
      {
        effective_year: row['EFFECTIVEYEAR'].to_i,
        state_name: row['STATENAME'],
        county_name: row['COUNTYNAME'],
        fips: row['FIPS'].to_i,
        trhd1: row['TRHD1'].to_i,
        trhd2: row['TRHD2'].to_i,
        trhd3: row['TRHD3'].to_i,
        trhd4: row['TRHD4'].to_i,
        trhd5: row['TRHD5'].to_i,
        trhd6: row['TRHD6'].to_i,
        trhd7: row['TRHD7'].to_i,
        trhd8: row['TRHD8'].to_i,
        msa: row['MSA'].to_i,
        msa_name: row['MSANAME'],
        version: row['VERSION'].to_i
      }.merge(date_attributes(row))
    end

    def date_attributes(row)
      {
        created: date_formatter(row['CREATED']),
        updated: date_formatter(row['UPDATED']),
        created_by: row['CREATEDBY'],
        updated_by: row['UPDATEDBY']
      }
    end

    def date_formatter(date)
      return nil unless date

      DateTime.strptime(date, '%F %H:%M:%S %z').to_s
    end
  end
end
