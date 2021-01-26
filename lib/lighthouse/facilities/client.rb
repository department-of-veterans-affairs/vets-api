# frozen_string_literal: true

require 'common/client/base'
require_relative 'nearby_response'
require_relative 'response'
require_relative 'configuration'

module Lighthouse
  module Facilities
    # Documentation located at:
    # https://developer.va.gov/explore/facilities/docs/facilities
    class Client < Common::Client::Base
      configuration Lighthouse::Facilities::Configuration

      ##
      # Request a list of facilities matching the params provided
      # @param params [Hash] a hash of parameter objects that must include bbox, ids, or lat and long
      #   see https://developer.va.gov/explore/facilities/docs/facilities for more options
      # @example  client.get_facilities(bbox: [60.99, 10.54, 180.00, 20.55])
      # @example  client.get_facilities(ids: 'vha_358,vba_358')
      # @example  client.get_facilities(lat: 10.54, long: 180.00, per_page: 50, page: 2)
      # @return [Array<Lighthouse::Facilities::Facility>]
      #
      def get_facilities(params)
        response = perform(:get, '/services/va_facilities/v0/facilities', params)
        facilities = Lighthouse::Facilities::Response.new(response.body, response.status).facilities
        facilities.reject!(&:mobile?) if params['exclude_mobile']
        facilities
      end

      ##
      # Request a list of nearby facilities based on calculated drive time bands
      # * Returns only health facilities
      # * Returns only facilities within a 90-minute drive time
      # * Does not respect per_page parameter
      # @param params [Hash] a hash of parameter objects that must include full address or lat and long
      #   see https://developer.va.gov/explore/facilities/docs/facilities for more options
      # @example  client.nearby(street_address: '123 Fake Street', city: 'Springfield', state: 'IL', zip: '62703')
      # @example  client.nearby(lat: 10.54, lng: 180.00)
      # @return [Array<Lighthouse::Facilities::NearbyFacility>]
      #
      def nearby(params)
        response = perform(:get, '/services/va_facilities/v0/nearby', params)
        Lighthouse::Facilities::NearbyResponse.new(response.body, response.status).facilities
      end
    end
  end
end
