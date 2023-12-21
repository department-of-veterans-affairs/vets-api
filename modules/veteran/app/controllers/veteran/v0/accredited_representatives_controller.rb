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
      PERMITTED_TYPES = %w[attorney veteran_service_officer].freeze
      PERMITTED_REPRESENTATIVE_SORTS = %w[distance_asc first_name_asc first_name_desc last_name_asc
                                          last_name_desc].freeze
      def index
        collection = Common::Collection.new(representative_klass, data: accreditation_query)
        resource = collection.paginate(**pagination_params)

        render json: resource.data,
               serializer: CollectionSerializer,
               each_serializer: serializer_klass,
               meta: resource.metadata
      end

      private

      def representative_klass
        @representative_klass ||= 'Veteran::Service::Representative'.constantize
      end

      def serializer_klass
        case search_params[:type]
        when 'attorney' then 'Veteran::Accreditation::AttorneySerializer'.constantize
        when 'veteran_service_officer' then 'Veteran::Accreditation::VeteranServiceOfficerSerializer'.constantize
        end
      end

      def base_query
        representative_klass.find_within_max_distance(search_params[:long],
                                                      search_params[:lat]).order(sort_query_string)
      end

      def type_adjusted_query
        case search_params[:type]
        when 'attorney' then attorney_query
        when 'veteran_service_officer' then veteran_service_officer_query
        end
      end

      def attorney_query
        base_query.select("veteran_representatives.*, #{distance_query_string}").where(
          '? = ANY(user_types) ', search_params[:type]
        )
      end

      def veteran_service_officer_query
        base_query
          .joins('JOIN LATERAL UNNEST(veteran_representatives.poa_codes) AS UnnestedPoaCode ON true')
          .joins('JOIN veteran_service_organizations ON UnnestedPoaCode = veteran_service_organizations.poa')
          .select("veteran_representatives.*, veteran_service_organizations.name AS organization_name, #{distance_query_string}") # rubocop:disable Layout/LineLength
          .where('? = ANY(veteran_representatives.user_types)', search_params[:type])
      end

      def find_with_name_similar_to(query)
        search_phrase = search_params[:name]
        fuzzy_search_threshold = Veteran::Service::Constants::FUZZY_SEARCH_THRESHOLD

        case search_params[:type]
        when 'attorney'
          query.where('word_similarity(?, full_name) >= ?', search_phrase, fuzzy_search_threshold)
        when 'veteran_service_officer'
          query.where('word_similarity(?, veteran_representatives.full_name) >= ? OR word_similarity(?, veteran_service_organizations.name) >= ?', # rubocop:disable Layout/LineLength
                      search_phrase, fuzzy_search_threshold, search_phrase, fuzzy_search_threshold)
        end
      end

      def accreditation_query
        query = type_adjusted_query

        search_params[:name] ? find_with_name_similar_to(query) : query
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
