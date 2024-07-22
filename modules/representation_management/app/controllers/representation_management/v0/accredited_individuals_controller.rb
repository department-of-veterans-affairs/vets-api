# frozen_string_literal: true

module RepresentationManagement
  module V0
    class AccreditedIndividualsController < ApplicationController
      service_tag 'lighthouse-veteran'
      skip_before_action :authenticate
      before_action :feature_enabled
      before_action :verify_type
      before_action :verify_sort
      before_action :verify_long
      before_action :verify_lat
      before_action :verify_distance

      DEFAULT_PAGE = 1
      DEFAULT_PER_PAGE = 10
      DEFAULT_SORT = 'distance_asc'
      PERMITTED_MAX_DISTANCES = [5, 10, 25, 50, 100, 200].freeze # in miles, no distance provided will default to "all"
      PERMITTED_SORTS = %w[distance_asc first_name_asc first_name_desc last_name_asc
                           last_name_desc].freeze
      PERMITTED_TYPES = %w[attorney claims_agent representative].freeze

      def index
        collection = Common::Collection.new(AccreditedIndividual, data: individual_query)
        resource = collection.paginate(**pagination_params)

        render json: serializer_class.new(resource.data, { meta: resource.metadata })
      end

      private

      def serializer_class
        'RepresentationManagement::AccreditedIndividuals::IndividualSerializer'.constantize
      end

      def base_query
        AccreditedIndividual
          .includes(:accredited_organizations)
          .select(select_query_string)
          .where(individual_type: search_params[:type])
          .order(sort_query_string)
      end

      def distance_query
        if search_params[:distance]
          base_query.find_within_max_distance(search_params[:long], search_params[:lat], max_distance)
        else
          base_query.where.not(location: nil)
        end
      end

      def individual_query
        if search_params[:name]
          distance_query.find_with_full_name_similar_to(search_params[:name])
        else
          distance_query
        end
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

      def select_query_string
        "accredited_individuals.*, #{distance_query_string}"
      end

      def distance_query_string
        ActiveRecord::Base
          .sanitize_sql_array([
                                'ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography,' \
                                'accredited_individuals.location) as distance',
                                search_params[:long],
                                search_params[:lat]
                              ])
      end

      def sort_query_string
        case sort_param
        when 'first_name_asc' then 'first_name ASC'
        when 'first_name_desc' then 'first_name DESC'
        when 'last_name_asc' then 'last_name ASC'
        when 'last_name_desc' then 'last_name DESC'
        else
          distance_asc_string
        end
      end

      def distance_asc_string
        ActiveRecord::Base.sanitize_sql_for_order(
          [
            Arel.sql(
              'ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, accredited_individuals.location) ASC'
            ),
            search_params[:long],
            search_params[:lat]
          ]
        )
      end

      def max_distance
        AccreditedRepresentation::Constants::METERS_PER_MILE * Integer(search_params[:distance])
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:find_a_representative_use_accredited_models)
      end

      def verify_type
        unless PERMITTED_TYPES.include?(search_params[:type])
          raise Common::Exceptions::InvalidFieldValue.new('type', search_params[:type])
        end
      end

      def verify_sort
        return unless search_params[:sort]
        unless PERMITTED_SORTS.include?(search_params[:sort])
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
