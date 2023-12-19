# frozen_string_literal: true

module Veteran
  module V0
    class AccreditedRepresentativesController < ApplicationController
      service_tag 'lighthouse-veteran'
      skip_before_action :authenticate
      before_action :feature_enabled
      before_action :verify_type
      before_action :verify_sort
      before_action :verify_long
      before_action :verify_lat

      DEFAULT_PAGE = 1
      DEFAULT_PER_PAGE = 10
      DEFAULT_SORT = 'distance_asc'

      PERMITTED_TYPES = %w[attorney representative].freeze

      PERMITTED_REPRESENTATIVE_SORTS = %w[distance_asc first_name_asc first_name_desc last_name_asc
                                          last_name_desc].freeze
      def index
        collection = Common::Collection.new(model_klass, data: accreditation_query)
        resource = collection.paginate(**pagination_params)

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: serializer_klass,
               meta: resource.metadata
      end

      private

      def model_klass
        @model_klass ||= 'Veteran::Service::Representative'.constantize
      end

      def serializer_klass
        'Veteran::Accreditation::RepresentativeSerializer'.constantize
      end

      def base_query
        model_klass.find_within_max_distance(search_params[:long],
                                             search_params[:lat]).order(sort_query_string)
      end

      def model_adjusted_query
        base_query.select("veteran_representatives.*, #{distance_query_string}").where(
          '? = ANY(user_types) ', search_params[:type]
        )
      end

      def accreditation_query
        if search_params[:name]
          model_adjusted_query.find_with_name_similar_to(search_params[:name])
        else
          model_adjusted_query
        end
      end

      def search_params
        params.require(%i[lat long type])
        params.permit(:lat, :long, :name, :page, :per_page, :sort, :type)
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
                                'ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, location) as distance',
                                search_params[:long],
                                search_params[:lat]
                              ])
      end

      def sort_query_string
        case sort_param
        when 'distance_asc'
          [Arel.sql('ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, location) ASC'),
           search_params[:long], search_params[:lat]]
        when 'name_asc' then 'name ASC'
        when 'name_desc' then 'name DESC'
        when 'first_name_asc' then 'first_name ASC'
        when 'first_name_desc' then 'first_name DESC'
        when 'last_name_asc' then 'last_name ASC'
        when 'last_name_desc' then 'last_name DESC'
        end
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:find_a_rep)
      end

      def verify_type
        unless PERMITTED_TYPES.include?(search_params[:type])
          raise Common::Exceptions::InvalidFieldValue.new('type', search_params[:type])
        end
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
    end
  end
end
