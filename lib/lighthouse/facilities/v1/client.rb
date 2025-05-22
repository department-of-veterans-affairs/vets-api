# frozen_string_literal: true

require 'common/client/base'
require_relative 'response'
require_relative '../configuration'

module Lighthouse
  module Facilities
    module V1
      # Documentation located at:
      # https://developer.va.gov/explore/facilities/docs/facilities
      class Client < Common::Client::Base
        configuration Lighthouse::Facilities::Configuration

        ##
        # Request a list of facilities matching the params provided
        # @param params [Hash] a hash of parameter objects that must include bbox, ids, or lat and long
        #   see https://developer.va.gov/explore/facilities/docs/facilities for more options
        # @example  client.get_facilities(bbox: [60.99, 10.54, 180.00, 20.55])
        # @example  client.get_facilities(facilityIds: 'vha_358,vba_358')
        # @example  client.get_facilities(lat: 10.54, long: 180.00, per_page: 50, page: 2)
        # @return [Array<Lighthouse::Facilities::Facility>]
        #
        def get_facilities(params)
          response = perform(:get, '/services/va_facilities/v1/facilities', params)
          facilities = Lighthouse::Facilities::V1::Response.new(response.body, response.status).facilities
          facilities.reject!(&:mobile?) if params['exclude_mobile']
          facilities
        end

        def get_paginated_facilities(params)
          response = perform(:get, '/services/va_facilities/v1/facilities', params)
          Lighthouse::Facilities::V1::Response.new(response.body, response.status)
        end
      end
    end
  end
end
