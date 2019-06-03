# frozen_string_literal: true

require 'facilities/client'

class NearbyFacility < ApplicationRecord
  class << self
    attr_writer :validate_on_load

    def query(params)
      if params[:street_address] && params[:city] && params[:state] && params[:zip]
        isochrone_response = request_isochrone(params)
        return get_facilities_in_isochrone(params, isochrone_response)
      end

      NearbyFacility.none
    end

    def request_isochrone(params)
      params[:drive_time] = '30' unless params[:drive_time]
      address = "#{params[:street_address]} #{params[:city]} #{params[:state]} #{params[:zip]}"
      query = {
        waypoint: address,
        maxtime: params[:drive_time],
        timeUnit: 'minute',
        dateTime: '07:30:00',
        optimize: 'timeWithTraffic',
        key: Settings.Bing.key
      }
      response = Faraday.get 'https://dev.virtualearth.net/REST/v1/Routes/Isochrones', query
      response.body
    end

    def get_facilities_in_isochrone(params, isochrone_response)
      isochrone = JSON.parse(isochrone_response)['resourceSets'][0]['resources'][0]['polygons'][0]['coordinates'][0]
      linestring = make_linestring(isochrone)
      make_polygon = "ST_MakePolygon(ST_GeomFromText('LINESTRING(#{linestring})'))"
      conditions = "ST_Intersects(#{make_polygon}, ST_MakePoint(long, lat))"
      facilities_query_base_instance = FacilitiesQuery::Base.new(params)
      BaseFacility::TYPES.flat_map do |facility_type|
        facilities_query_base_instance.get_facility_data(conditions, params[:type], facility_type, params[:services])
      end
    end

    def make_linestring(polygon)
      polygon.map{|point| "#{point[1]} #{point[0]}"}.join(',')
    end

    def per_page
      20
    end

    def max_per_page
      100
    end
  end
end
