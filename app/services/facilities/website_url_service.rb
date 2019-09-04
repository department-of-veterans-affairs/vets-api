# frozen_string_literal: true

require 'csv'

module Facilities
  class WebsiteUrlService
    FACILITY_TYPES = {
      'va_benefits_facility' => 'VBA',
      'va_health_facility' => 'VHA',
      'va_cemetery' => 'NCA',
      'vet_center' => 'VC'
    }.freeze

    def initialize
      source = Rails.root.join('lib', 'facilities', 'website_data', 'websites.csv')
      station_websites = CSV.read(source, headers: true)
      @websites = map_websites_to_stations(station_websites)
    end

    def find_for_station(id, type)
      unique_id = "#{id}_#{FACILITY_TYPES[type]}"
      entry = @websites[unique_id]
      entry.nil? ? '' : entry
    end

    private

    def map_websites_to_stations(station_websites)
      station_websites.each_with_object({}) do |station, hash|
        unique_id = "#{station['StationNum']}_#{station['Org']}"
        hash[unique_id] = station['Website_URL']
      end
    end
  end
end
