# frozen_string_literal: true

require 'facilities/client'
require 'common/exceptions'

class NearbyFacility < ApplicationRecord


  class << self
    attr_writer :validate_on_load

    def query(params)
      return NearbyFacility.none unless params[:street_address] && params[:city] && params[:state] && params[:zip]
      waypoint = "#{params[:street_address]} #{params[:city]} #{params[:state]} #{params[:zip]}"
      isochrone_response = request_isochrone(waypoint, params)
      get_facilities_in_isochrone(params, isochrone_response)
    end

    def query_by_lat_lng(params)
      return NearbyFacility.none unless params[:lat] && params[:lng]
      waypoint = "#{params[:lat]},#{params[:lng]}"
      isochrone_response = request_isochrone(waypoint, params)
      get_facilities_in_isochrone(params, isochrone_response)
    end

    def request_isochrone(waypoint, params)
      params[:drive_time] = '30' unless params[:drive_time]
      # list of all parameters can be found at https://docs.microsoft.com/en-us/bingmaps/rest-services/routes/calculate-an-isochrone#template-parameters
      # we are currently using today at 7:30 AM (local time for the waypoint) for traffic modelling
      query = {
        waypoint: waypoint,
        maxtime: params[:drive_time],
        timeUnit: 'minute',
        dateTime: '07:30:00',
        optimize: 'timeWithTraffic',
        key: Settings.bing.key
      }

      response = Faraday.get "#{Settings.bing.base_api_url}/Isochrones", query
      response_body = JSON.parse(response.body)
      handle_bing_errors(response_body, response.headers)

      response_body
    end

    def get_facilities_in_isochrone(params, isochrone_response)
      # an example response can be found at https://docs.microsoft.com/en-us/bingmaps/rest-services/examples/isochrone-example
      isochrone = parse_isochrone(isochrone_response)

      if isochrone.present?
        linestring = make_linestring(isochrone)
        # convert linestring into a polygon
        make_polygon = "ST_MakePolygon(ST_GeomFromText('LINESTRING(#{linestring})'))"
        # find all facilities that lie inside of the polygon
        conditions = "ST_Intersects(#{make_polygon}, ST_MakePoint(long, lat))"
        facilities_query_base_instance = FacilitiesQuery::Base.new(params)
        BaseFacility::TYPES.flat_map do |facility_type|
          facilities_query_base_instance.get_facility_data(conditions, params[:type], facility_type, params[:services])
        end
      else
        NearbyFacility.none
      end
    end

    def make_linestring(polygon)
      # convert array of latitude and longitude points into a string of comma-separated longitude and latitude points
      polygon.map { |point| "#{point[1]} #{point[0]}" }.join(',')
    end

    def parse_isochrone(response_json)
      response_json.try(:[], 'resourceSets')
                   &.first
                   .try(:[], 'resources')
                   &.first
                   .try(:[], 'polygons')
                   &.first
                   .try(:[], 'coordinates')
                   &.first
    end

    def handle_bing_errors(response_body, headers)
      if response_body['errors'].present? && response_body['errors'].size.positive?
        raise Common::Exceptions::BingServiceError, (response_body['errors'].flat_map { |h| h['errorDetails'] })
      elsif headers['x-ms-bm-ws-info'].to_i == 1 && empty_resource_set?(response_body)
        # https://docs.microsoft.com/en-us/bingmaps/rest-services/status-codes-and-error-handling
        raise Common::Exceptions::BingServiceError, 'Bing server overloaded'
      end
    end

    def empty_resource_set?(response_body)
      response_body['resourceSets'].size.zero? || response_body['resourceSets'][0]['estimatedTotal'].zero?
    end

    def per_page
      20
    end

    def max_per_page
      100
    end
  end
end
