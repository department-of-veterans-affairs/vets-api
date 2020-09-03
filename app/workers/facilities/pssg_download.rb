# frozen_string_literal: true

require 'rgeo/geo_json'
require 'sentry_logging'
require 'facilities/drivetime_bands/client'

module Facilities
  class PSSGDownload
    include Sidekiq::Worker
    include SentryLogging

    def perform
      @drivetime_band_client = Facilities::DrivetimeBands::Client.new
      begin
        download_data
      rescue => e
        log_exception_to_sentry(e)
      end
    end

    private

    def create_and_save_drive_time_data(drive_time_data)
      @attributes = drive_time_data&.dig('attributes')
      @band_name = @attributes&.dig('Name')
      @rings = drive_time_data&.dig('geometry', 'rings')
      @vssc_extract_date = DateTime.strptime(@attributes&.dig('EXTRDATE').to_s, '%Q')

      # temporary logging
      Rails.logger.info "PSSG Band not downloaded: Missing rings: #{@band_name}" if @rings.blank?
      return if @rings.blank?

      @id = @attributes&.dig('Sta_No')&.strip
      facility = Facilities::VHAFacility.find_by(unique_id: @id)

      # temporary logging
      Rails.logger.info "PSSG Band not downloaded: Facility #{@id} dne. Band #{@band_name}" if facility.nil?
      return if facility.nil?

      insert_or_update_band(facility)
    rescue => e
      log_exception_to_sentry(e, 'Band name' => @band_name)
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

    def insert_or_update_band(facility)
      drive_time_band = facility.drivetime_bands.find_by(vha_facility_id: @id, name: @band_name)

      if drive_time_band.nil?
        drive_time_band = facility.drivetime_bands.new(vha_facility_id: @id, name: @band_name)
        drive_time_band.unit = 'minutes'
        drive_time_band.min = round_band(@attributes&.dig('FromBreak'))
        drive_time_band.max = round_band(@attributes&.dig('ToBreak'))
        drive_time_band.polygon = extract_polygon(@rings)
        drive_time_band.vssc_extract_date = @vssc_extract_date

        drive_time_band.save
        # Rails.logger.info "PSSG Band successfully inserted: #{@band_name}" # temporary logging
      elsif @vssc_extract_date > drive_time_band.try(:vssc_extract_date)
        # rubocop:disable Rails/SkipsModelValidations
        drive_time_band.update_columns(
          min: round_band(@attributes&.dig('FromBreak')),
          max: round_band(@attributes&.dig('ToBreak')),
          polygon: extract_polygon(@rings),
          vssc_extract_date: @vssc_extract_date,
          updated_at: Time.zone.now
        )
        # rubocop:enable Rails/SkipsModelValidations
        # Rails.logger.info "PSSG Band successfully updated: #{@band_name}" # temporary logging
        # else
        #   Rails.logger.info "PSSG Band not updated: Facility #{@id}. Band #{@band_name}" # temporary logging
      end
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
