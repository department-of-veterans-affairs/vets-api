# frozen_string_literal: true

require 'facilities/client'

class NearbyFacility < ApplicationRecord
  class << self
    attr_writer :validate_on_load

    def query(params)
      return NearbyFacility.none unless params[:street_address] && params[:city] && params[:state] && params[:zip]
      isochrone_response = request_isochrone(params)
      get_facilities_in_isochrone(params, isochrone_response)
    end

    def request_isochrone(params)
      params[:drive_time] = '30' unless params[:drive_time]
      address = "#{params[:street_address]} #{params[:city]} #{params[:state]} #{params[:zip]}"
      # list of all parameters can be found at https://docs.microsoft.com/en-us/bingmaps/rest-services/routes/calculate-an-isochrone#template-parameters
      # we are currently using today at 7:30 AM (local time for the waypoint) for traffic modelling
      query = {
        waypoint: address,
        maxtime: params[:drive_time],
        timeUnit: 'minute',
        dateTime: '07:30:00',
        optimize: 'timeWithTraffic',
        key: Settings.bing.key
      }
      response = Faraday.get "#{Settings.bing.base_api_url}/Isochrones", query
      response.body
    end

    def get_facilities_in_isochrone(params, isochrone_response)
      # an example response can be found at https://docs.microsoft.com/en-us/bingmaps/rest-services/examples/isochrone-example
      isochrone = JSON.parse(isochrone_response)['resourceSets'][0]['resources'][0]['polygons'][0]['coordinates'][0]
      linestring = make_linestring(isochrone)
      # convert linestring into a polygon
      make_polygon = "ST_MakePolygon(ST_GeomFromText('LINESTRING(#{linestring})'))"
      # find all facilities that lie inside of the polygon
      conditions = "ST_Intersects(#{make_polygon}, ST_MakePoint(long, lat))"
      facilities_query_base_instance = FacilitiesQuery::Base.new(params)
      BaseFacility::TYPES.flat_map do |facility_type|
        facilities_query_base_instance.get_facility_data(conditions, params[:type], facility_type, params[:services])
      end
    end

    def make_linestring(polygon)
      # convert array of latitude and longitude points into a string of comma-separated longitude and latitude points
      polygon.map { |point| "#{point[1]} #{point[0]}" }.join(',')
    end

    def per_page
      20
    end

    def max_per_page
      100
    end
  end
end
