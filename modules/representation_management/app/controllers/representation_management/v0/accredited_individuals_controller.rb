# frozen_string_literal: true

module RepresentationManagement
  module V0
    class AccreditedIndividualsController < ApplicationController
      service_tag 'representation-management'
      skip_before_action :authenticate
      before_action :feature_enabled

      DEFAULT_PAGE = 1
      DEFAULT_PER_PAGE = 10
      DEFAULT_SORT = 'distance_asc'

      def index
        search = RepresentationManagement::AccreditedIndividualSearch.new(search_params)

        if search.valid?
          collection = Common::Collection.new(AccreditedIndividual, data: individual_query)
          resource = collection.paginate(**pagination_params)
          data = resource.data
          options = { meta: resource.metadata }

          render json: RepresentationManagement::AccreditedIndividuals::IndividualSerializer.new(data, options)
        else
          render json: { errors: search.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

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
        @search_params ||= begin
          params.require(%i[lat long type])
          params.permit(:distance, :lat, :long, :name, :page, :per_page, :sort, :type)
        end
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
    end
  end
end
