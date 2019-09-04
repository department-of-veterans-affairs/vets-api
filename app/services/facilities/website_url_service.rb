# frozen_string_literal: true

require 'csv'

module Facilities
  class WebsiteUrlService
    def initialize
      source = Rails.root.join('lib', 'facilities', 'website_data', 'websites.csv')
      station_websites = CSV.read(source, headers: true).to_h
      @websites = map_websites_to_stations(station_websites)
    end

    def find_for_station(id)
      entry = @websites[id]
      entry.nil? ? '' : entry['Website_URL']
    end

    private

    def map_websites_to_stations(station_websites)
      station_websites.each_with_object({}) do |station, hash|
        station_id = station['StationNum']
        hash[station_id] = station['Website_URL']
      end
    end
  end
end
