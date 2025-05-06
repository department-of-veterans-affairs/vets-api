# frozen_string_literal: true

module Veteran
  module V0
    class BaseAccreditedRepresentativesController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled
      before_action :verify_sort
      before_action :verify_long
      before_action :verify_lat
      before_action :verify_distance

      DEFAULT_PAGE = 1
      DEFAULT_PER_PAGE = 10
      DEFAULT_SORT = 'distance_asc'
      PERMITTED_MAX_DISTANCES = [5, 10, 25, 50, 100, 200].freeze # in miles, no distance provided will default to "all"
      PERMITTED_REPRESENTATIVE_SORTS = %w[distance_asc first_name_asc first_name_desc last_name_asc
                                          last_name_desc].freeze

      def index
        collection = Common::Collection.new(Veteran::Service::Representative, data: representative_query)
        resource = collection.paginate(**pagination_params)
        render json: serializer_class.new(resource.data, { meta: resource.metadata })
      end

      private

      def serializer_class
        raise NotImplementedError, 'serializer_class must be implemented'
      end

      def base_query
        query = if search_params[:distance]
                  Veteran::Service::Representative.find_within_max_distance(search_params[:long],
                                                                            search_params[:lat],
                                                                            max_distance)
                else
                  Veteran::Service::Representative.where.not(location: nil)
                end

        query.order(sort_query_string)
      end

      def search_params
        params.require(%i[lat long type])
        params.permit(:distance, :lat, :long, :name, :page, :per_page, :sort, :type)
      end

      def pagination_params
        {
          page: search_params[:page] || DEFAULT_PAGE,
          per_page: search_params[:per_page] || DEFAULT_PER_PAGE
        }
      end

      def sort_param
        search_params[:sort] || DEFAULT_SORT
      end

      def distance_query_string
        ActiveRecord::Base
          .sanitize_sql_array([
                                'ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, veteran_representatives.location) as distance', # rubocop:disable Layout/LineLength
                                search_params[:long],
                                search_params[:lat]
                              ])
      end

      def sort_query_string
        case sort_param
        when 'distance_asc'
          ActiveRecord::Base.sanitize_sql_for_order(
            [Arel.sql('ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, veteran_representatives.location) ASC'), # rubocop:disable Layout/LineLength
             search_params[:long],
             search_params[:lat]]
          )
        when 'name_asc' then 'name ASC'
        when 'name_desc' then 'name DESC'
        when 'first_name_asc' then 'first_name ASC'
        when 'first_name_desc' then 'first_name DESC'
        when 'last_name_asc' then 'last_name ASC'
        when 'last_name_desc' then 'last_name DESC'
        end
      end

      def max_distance
        Veteran::Service::Constants::METERS_PER_MILE * Integer(search_params[:distance])
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:find_a_representative_enable_api)
      end

      def verify_sort
        return unless search_params[:sort]
        unless PERMITTED_REPRESENTATIVE_SORTS.include?(search_params[:sort])
          raise Common::Exceptions::InvalidFieldValue.new('sort', search_params[:sort])
        end
      end

      def verify_long
        long = Float(search_params[:long])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('long', search_params[:long])
      else
        raise Common::Exceptions::InvalidFieldValue.new('long', search_params[:long]) unless (-180..180).cover?(long)
      end

      def verify_lat
        lat = Float(search_params[:lat])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('lat', search_params[:lat])
      else
        raise Common::Exceptions::InvalidFieldValue.new('lat', search_params[:lat]) unless (-90..90).cover?(lat)
      end

      def verify_distance
        return unless search_params[:distance]

        distance = Integer(search_params[:distance])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('distance', search_params[:distance])
      else
        unless PERMITTED_MAX_DISTANCES.include?(distance)
          raise Common::Exceptions::InvalidFieldValue.new('distance',
                                                          search_params[:distance])
        end
      end
    end
  end
end
