# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/facilities/response'

module Lighthouse
  module Facilities
    # Documentation located at:
    # https://developer.va.gov/explore/facilities/docs/facilities
    class Client < Common::Client::Base
      configuration Lighthouse::Facilities::Configuration

      ##
      # Request a single facility
      # @param id [String] the id of the facility created by combining the type of facility and station number
      # @example  client.get_by_id(vha_358)
      # @return [Lighthouse::Facilities::Facility]
      #
      def get_by_id(id)
        response = perform(:get, "/services/va_facilities/v0/facilities/#{id}", nil)
        Lighthouse::Facilities::Response.new(response.body, response.status).facility
      end

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
        Lighthouse::Facilities::Response.new(response.body, response.status).facilities
      end
    end
  end
end
