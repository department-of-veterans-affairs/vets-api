# frozen_string_literal: true

require 'csv'
require 'common/exceptions'
require 'sentry_logging'

module Facilities
  class DentalServiceError < StandardError
  end

  class DentalServiceReloadJob
    include Sidekiq::Worker
    include SentryLogging

    def fetch_dental_service_data(file)
      CSV.read(file, headers: true)
    rescue => e
      raise DentalServiceError, "Failed to read CSV file: #{file} - caused by: #{e.cause}"
    end

    def update_cache(facilities)
      facilities.each do |facility_id|
        attrs = { station_number: facility_id,
                  local_updated: Time.now.utc.iso8601 }
        dental_record = FacilityDentalService.find_or_build(facility_id)
        dental_record.update(attrs)
      end
    end

    def remove_invalid_keys(facility_keys)
      invalidate = FacilityDentalService.keys - facility_keys
      invalidate.each { |x| FacilityDentalService.delete(x) }
    end

    def parse_dental_service_data(records)
      records.map { |r| r['unique_id'] }
    end

    def update_dental_service_data
      dental_file = Rails.root.join('lib', 'facilities', 'dental_service_data', 'dental_services.csv')
      records = fetch_dental_service_data(dental_file)
      facilities = parse_dental_service_data(records)
      update_cache(facilities)
      remove_invalid_keys(facilities)
    rescue Facilities::DentalServiceError => e
      log_exception_to_sentry(e)
    end

    def perform
      update_dental_service_data
    end
  end
end
