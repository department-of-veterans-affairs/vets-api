# frozen_string_literal: true

require 'rgeo/geo_json'
require 'sentry_logging'

module Facilities
  class PSSGDownload
    include Sidekiq::Worker
    include SentryLogging

    def perform
      @drivetime_band_client = Facilities::DrivetimeBandClient.new
      begin
        download_data
      rescue => e
        log_exception_to_sentry(e, 'Band name' => @band_name)
      end
    end

    private

    def create_and_save_drive_time_data(drive_time_data)
      attributes = drive_time_data&.dig('attributes')
      rings = drive_time_data&.dig('geometry', 'rings')

      # temporary logging
      Rails.logger.info "PSSG Band not downloaded: Missing rings: #{attributes&.dig('Name')}" if rings.blank?
      return if rings.blank?

      id = attributes&.dig('Sta_No')&.strip
      facility = Facilities::VHAFacility.find_by(unique_id: id)

      # temporary logging
      Rails.logger.info "PSSG Band not downloaded: Facility #{id} dne. Band #{attributes&.dig('Name')}" if facility.nil?
      return if facility.nil?

      name = attributes&.dig('Name')
      drive_time_band = facility.drivetime_bands.find_or_initialize_by(vha_facility_id: id, name: name)
      drive_time_band.unit = 'minutes'
      drive_time_band.min = round_band(attributes&.dig('FromBreak'))
      drive_time_band.max = round_band(attributes&.dig('ToBreak'))
      drive_time_band.name = name
      @band_name = name
      drive_time_band.polygon = extract_polygon(rings)

      Rails.logger.info "PSSG Band successfully saved: #{name}" # temporary logging
      drive_time_band.save
      facility.save
    end

    def round_band(band)
      if (band % 10).zero?
        band
      else
        (band.to_i / 10 + 1) * 10
      end
    end

    def extract_polygon(rings)
      geojson = "{\"type\":\"Polygon\",\"coordinates\":#{rings}}"
      spherical_factory = RGeo::Geographic.spherical_factory(srid: 4326, uses_lenient_assertions: true)
      RGeo::GeoJSON.decode(geojson, geo_factory: spherical_factory)
    end

    def download_data
      offset = 0
      limit = 30
      loop do
        response = @drivetime_band_client.get_drivetime_bands(offset, limit)

        break if response.blank?

        response.each(&method(:create_and_save_drive_time_data))
        offset += limit
      end
    end
  end
end
