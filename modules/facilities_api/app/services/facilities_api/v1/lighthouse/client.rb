# frozen_string_literal: true

require 'common/client/base'
require_relative 'response'
require_relative 'configuration'

module FacilitiesApi
  module V1
    module Lighthouse
      # Documentation located at:
      # https://developer.va.gov/explore/facilities/docs/facilities
      class Client < Common::Client::Base
        configuration V1::Lighthouse::Configuration

        ##
        # Request a single facility
        # @param id [String] the id of the facility created by combining the type of facility and station number
        # @example  client.get_by_id(vha_358)
        # @return [Lighthouse::Facilities::Facility]
        #
        def get_by_id(id)
          response = perform(:get, "/services/va_facilities/v0/facilities/#{id}", nil)
          V1::Lighthouse::Response.new(response.body, response.status).facility
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

        # Lighthouse only accepts the following param combinations
        # !bbox[],       !lat, !long, !radius, !state, !type,  visn, !zip
        #  bbox[],       !lat, !long, !radius, !state,        !visn, !zip
        # !bbox[],       !lat, !long, !radius,  state,        !visn, !zip
        # !bbox[],       !lat, !long, !radius, !state,        !visn,  zip
        # !bbox[],        lat,  long,          !state,        !visn, !zip
        # !bbox[],  ids, !lat, !long, !radius, !state,        !visn, !zip

        def get_facilities(params)
          filtered_params = params.slice(:ids, :mobile, :page, :per_page, :services, :type, :visn)

          if    params.key?(:bbox)
            filtered_params.merge!(params.slice(:bbox))
          elsif params.key?(:lat) && params.key?(:long)
            filtered_params.merge!(params.slice(:lat, :long, :radius))
          elsif params.key?(:state)
            filtered_params.merge!(params.slice(:state))
          elsif params.key?(:zip)
            filtered_params.merge!(params.slice(:zip))
          elsif params.key?(:ids)
            filtered_params.merge!(params.slice(:ids))
          end

          response = perform(:get, '/services/va_facilities/v0/facilities', filtered_params)
          V1::Lighthouse::Response.new(response.body, response.status).facilities
        end
      end
    end
  end
end
