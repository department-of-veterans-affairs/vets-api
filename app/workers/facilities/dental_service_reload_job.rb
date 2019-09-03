# frozen_string_literal: true

require 'csv'

# require 'facilities/bulk_json_client'
require 'common/exceptions'
# require 'facility_access'
require 'sentry_logging'

module Facilities
  class DentalServiceError < StandardError
  end

  class DentalServiceReloadJob
    include Sidekiq::Worker
    include SentryLogging

    def fetch_dental_service_data(file)
      CSV.read(file, headers: true)
    rescue StandardError => e
      raise DentalServiceError, "Failed to read CSV file: #{file} - caused by: #{e.cause}"
    end

    def update_cache(model, facilities)
      facilities.each_key do |k|
        attrs = { station_number: k,
                  local_updated: Time.now.utc.iso8601 }
        obj = model.find(k)
        if obj
          obj.update(attrs)
        else
          model.create(attrs)
        end
      end
    end

    def invalidate_removed(model, facility_keys)
      invalidate = model.keys - facility_keys
      invalidate.each { |x| model.delete(x) }
      logger.info "Removed #{invalidate.size} obsolete entries from cache"
    end

    def parse_dental_service_data(records)
      facilities = Hash.new { |h, k| h[k] = {} }
      records.each do |rec|
        id = rec['unique_id']
        facilities[id]
      end
      facilities
    end

    def update_dental_service_data
      dental_file = Rails.root.join('lib', 'facilities', 'dental_service_data', 'dental_services.csv')
      records = fetch_dental_service_data(dental_file)
      facilities = parse_dental_service_data(records)
      update_cache(FacilityDentalService, facilities)
      logger.info "Updated facility dental service cache for #{facilities.size} facilities"
      invalidate_removed(FacilityDentalService, facilities.keys)
    rescue Facilities::DentalServiceError => e
      log_exception_to_sentry(e)
    end

    def perform
      update_dental_service_data
    end
  end
end
