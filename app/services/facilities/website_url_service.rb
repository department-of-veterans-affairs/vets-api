# frozen_string_literal: true

require 'csv'

module Facilities
  class WebsiteUrlService
    def initialize
      source = Rails.root.join('lib', 'facilities', 'website_data', 'websites.csv')
      station_websites = CSV.read(source, headers: true)
      @websites = map_websites_to_stations(station_websites)
    end

    def find_for_station(id, type)
      unique_id = "#{BaseFacility::PREFIX_MAP[type]}_#{id}"
      @websites[unique_id]
    end

    private

    def map_websites_to_stations(station_websites)
      station_websites.each_with_object({}) do |station, hash|
        org = station['Org'].downcase unless station['Org'].nil?
        unique_id = "#{org}_#{station['StationNum'].upcase}"
        hash[unique_id] = station['Website_URL']
      end
    end
  end
end
