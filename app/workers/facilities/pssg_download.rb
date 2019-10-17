# frozen_string_literal: true

require 'rgeo/geo_json'

module Facilities
  class PSSGDownload
    include Sidekiq::Worker
    include SentryLogging

    def perform
      @drivetime_band_client = Facilities::DrivetimeBandClient.new
      download_data
    end

    private

    def create_and_save_drive_time_data(drive_time_data)
      attributes = drive_time_data&.dig('attributes')

      id = extract_id(attributes)
      vha_id = "vha_#{id}"
      facility = BaseFacility.find_facility_by_id(vha_id)
      return if facility.nil?

      begin
        drive_time_band = facility.drivetime_bands.find_or_initialize_by(vha_facility_id: id)
        drive_time_band.min = attributes&.dig('FromBreak')
        drive_time_band.max = attributes&.dig('ToBreak')
        drive_time_band.name = attributes&.dig('Name')
        drive_time_band.polygon = extract_polygon(drive_time_data)
        drive_time_band.save
        facility.save
      rescue => e
        logger.error e.message
      end
    end

    def extract_id(attributes)
      name = attributes&.dig('Name')
      name.partition(':')&.first&.strip!
    end

    def extract_polygon(drive_time_data)
      rings = drive_time_data&.dig('geometry', 'rings')
      geojson = "{\"type\":\"Polygon\",\"coordinates\":#{rings}}"
      RGeo::GeoJSON.decode(geojson)
    end

    def download_data
      offset = 0
      loop do
        response = @drivetime_band_client.get_drivetime_bands(offset, 1)
        break if response.nil?

        response.each(&method(:create_and_save_drive_time_data))
        offset += 1
      end
    end
  end
end
