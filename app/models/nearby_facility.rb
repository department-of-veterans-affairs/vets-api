# frozen_string_literal: true

require 'facilities/client'

class NearbyFacility < ApplicationRecord
  class << self
    attr_writer :validate_on_load

    def query(params)
      json_from_file = File.read(Rails.root.join('modules', 'va_facilities', 'nearby.json'))
      mocked_response = JSON.parse(json_from_file)
      return mocked_response if params[:street_address] && params[:city] && params[:state] && params[:zip]

      NearbyFacility.none
    end

    def per_page
      20
    end

    def max_per_page
      100
    end
  end
end
