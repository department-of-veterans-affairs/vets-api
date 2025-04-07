# frozen_string_literal: true

require 'common/client/base'
require_relative 'response'
require_relative 'configuration'

module FacilitiesApi
  module V2
    module Lighthouse
      # Documentation located at:
      # https://developer.va.gov/explore/api/va-facilities/docs
      class Client < Common::Client::Base
        configuration V2::Lighthouse::Configuration

        ##
        # Request a single facility
        # @param id [String] the id of the facility created by combining the type of facility and station number
        # @example  client.get_by_id(vha_358)
        # @return [V2::Lighthouse::Facility]
        #
        def get_by_id(id)
          response = perform(:get, "/services/va_facilities/v1/facilities/#{id}", nil)
          begin
            # Try to get services for facility
            response_services = perform(:get, "/services/va_facilities/v1/facilities/#{id}/services", nil)
            V2::Lighthouse::Response.new(response.body, response.status).facility_with_services(response_services.body)
          rescue => _e
            # Handle without services as fallback
            V2::Lighthouse::Response.new(response.body, response.status).facility
          end
        end

        ##
        # Request a list of all facilities or only facilities matching the params provided
        # @param params [Hash] a hash of parameter objects
        #   see https://developer.va.gov/explore/api/va-facilities/docs for more options
        # @example  client.get_facilities(bbox: [60.99, 10.54, 180.00, 20.55])
        # @example  client.get_facilities(facilityIds: 'vha_358,vba_358')
        # @example  client.get_facilities(lat: 10.54, long: 180.00, per_page: 50, page: 2)
        # @return [Array<V2::Lighthouse::Facility>]
        #
        def get_facilities(params)
          filtered_params = params.slice(:facilityIds, :mobile, :page, :per_page, :services, :type, :visn)

          if params.key?(:bbox)
            filtered_params.merge!(params.slice(:bbox))
          elsif params.key?(:lat) && params.key?(:long)
            filtered_params.merge!(params.slice(:lat, :long, :radius))
          elsif params.key?(:state)
            filtered_params.merge!(params.slice(:state))
          elsif params.key?(:zip)
            filtered_params.merge!(params.slice(:zip))
          end

          response = perform(:get, '/services/va_facilities/v1/facilities', filtered_params)
          V2::Lighthouse::Response.new(response.body, response.status).facilities
        end

        ##
        # Request a list of all facilities or only facilities matching the params provided
        # @param params [Hash] a hash of parameter objects
        #   see https://developer.va.gov/explore/api/va-facilities/docs for more options
        # @example  client.get_paginated_facilities(bbox: [60.99, 10.54, 180.00, 20.55])
        # @example  client.get_paginated_facilities(facilityIds: 'vha_358,vba_358')
        # @example  client.get_paginated_facilities(lat: 10.54, long: 180.00, per_page: 50, page: 2)
        # @return [V2::Lighthouse::Response]
        #
        def get_paginated_facilities(params)
          response = perform(:get, '/services/va_facilities/v1/facilities', params)
          V2::Lighthouse::Response.new(response.body, response.status)
        end
      end
    end
  end
end
