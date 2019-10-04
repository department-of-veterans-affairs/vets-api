# frozen_string_literal: true

require 'csv'
require 'common/exceptions'
require 'sentry_logging'

module Facilities
  class MentalHealthDownloadError < StandardError
  end

  class MentalHealthReloadJob
    include Sidekiq::Worker
    include SentryLogging

    def fetch_mental_health_data
      mental_file = Rails.root.join('lib', 'facilities', 'mental_health_data', 'mental_health_phone_numbers.csv')
      CSV.read(mental_file, headers: true)
    rescue => e
      raise MentalHealthDownloadError, "Failed to download mental health data: #{e.cause}"
    end

    def update_cache(records)
      records.each do |r|
        ext = convert_extension(r['Extension'])

        attrs = {
          station_number: r['StationNumber'],
          mh_phone: r['MHPhone'],
          mh_ext: ext,
          modified: r['Modified'],
          local_updated: Time.now.utc.iso8601
        }

        mental_health_record = FacilityMentalHealth.find_or_build(r['StationNumber'])
        mental_health_record.update(attrs)
      end
    end

    def convert_extension(ext)
      if %w[NULL 0].include?(ext)
        nil
      else
        ext
      end
    end

    def remove_invalid(record_keys)
      invalid = FacilityMentalHealth.keys - record_keys
      invalid.each { |x| FacilityMentalHealth.delete(x) }
    end

    def update_mental_health_data
      records = fetch_mental_health_data
      update_cache(records)
      remove_invalid(records.map { |r| r['StationNumber'] })
    rescue Facilities::MentalHealthDownloadError => e
      log_exception_to_sentry(e)
    end

    def perform
      update_mental_health_data
    end
  end
end
