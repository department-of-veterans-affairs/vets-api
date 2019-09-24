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

    def update_cache(model, records)
      records.each do |r|
        ext = if r['Extension'] == '0' || r['Extension'] == 'NULL'
                nil
              else
                r['Extension']
              end

        attrs = {
          station_number: r['StationNumber'],
          mh_phone: r['MHPhone'],
          mh_ext: ext,
          modified: r['Modified'],
          local_updated: Time.now.utc.iso8601
        }

        obj = model.find(r['StationNumber'])

        if obj
          obj.update(attrs)
        else
          model.create(attrs)
        end
      end
    end

    def remove_invalid(model, record_keys)
      invalid = model.keys - record_keys
      invalid.each { |x| model.delete(x) }
      logger.info "Removed #{invalid.size} obsolete entries from cache"
    end

    def update_mental_health_data
      records = fetch_mental_health_data
      update_cache(FacilityMentalHealth, records)
      remove_invalid(FacilityMentalHealth, records.map { |r| r['StationNumber'] })
    rescue Facilities::MentalHealthDownloadError => e
      log_exception_to_sentry(e)
    end

    def perform
      update_mental_health_data
    end
  end
end
