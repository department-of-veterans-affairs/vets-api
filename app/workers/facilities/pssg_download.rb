# frozen_string_literal: true

require 'rgeo/geo_json'

module Facilities
  class PSSGDownloadError < StandardError
  end

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

      id = attributes&.dig('Sta_No')&.strip
      facility = Facilities::VHAFacility.find_by(unique_id: id)
      return if facility.nil?

      begin
        name = attributes&.dig('Name')
        drive_time_band = facility.drivetime_bands.find_or_initialize_by(vha_facility_id: id, name: name)
        drive_time_band.unit = 'minutes'
        drive_time_band.min = attributes&.dig('FromBreak')
        drive_time_band.max = attributes&.dig('ToBreak')
        drive_time_band.name = name
        drive_time_band.polygon = extract_polygon(drive_time_data)
        drive_time_band.save
        facility.save
      rescue => e
        raise PSSGDownloadError, e.message
      end
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
        break if response.blank?

        response.each(&method(:create_and_save_drive_time_data))
        offset += 1
      end
    end
  end
end
