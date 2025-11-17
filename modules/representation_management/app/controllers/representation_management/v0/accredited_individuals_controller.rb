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
          # Wrap Veteran::Service::Representative records in adapter if needed
          if use_veteran_model?
            data = individual_query.map do |record|
              RepresentationManagement::VeteranRepresentativeAdapter.new(record)
            end
            model_class = RepresentationManagement::VeteranRepresentativeAdapter
          else
            data = individual_query
            model_class = AccreditedIndividual
          end

          collection = Common::Collection.new(model_class, data:)
          resource = collection.paginate(**pagination_params)
          options = { meta: resource.metadata }

          render json: RepresentationManagement::AccreditedIndividuals::IndividualSerializer.new(resource.data, options)
        else
          render json: { errors: search.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def base_query
        model_class = determine_model_class

        if use_veteran_model?
          # Veteran::Service::Representative query
          model_class
            .includes(:organizations)
            .select(select_query_string_for_veteran)
            .where(where_clause_for_veteran_type)
            .order(sort_query_string_for_veteran)
        else
          # AccreditedIndividual query
          model_class
            .includes(:accredited_organizations)
            .select(select_query_string)
            .where(individual_type: type_param)
            .order(sort_query_string)
        end
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
          if use_veteran_model?
            find_veteran_with_name_similar_to(distance_query)
          else
            distance_query.find_with_full_name_similar_to(search_params[:name])
          end
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

      def type_param
        # This method accepts the types for Veteran::Service::Representative and AccreditedIndividual
        # and maps them to the individual_type used in AccreditedIndividual.
        case search_params[:type]
        when 'claims_agent', 'claim_agents'
          'claims_agent'
        when 'representative', 'veteran_service_officer'
          'representative'
        when 'attorney' # attorney is the same across Veteran::Service::Representative and AccreditedIndividual
          'attorney'
        else
          raise ArgumentError, "Invalid type: #{search_params[:type]}"
        end
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

      # Data source determination methods

      def current_data_source_log
        @current_data_source_log ||=
          RepresentationManagement::AccreditationDataIngestionLog.most_recent_successful
      end

      def use_veteran_model?
        current_data_source_log&.trexler_file?
      end

      def determine_model_class
        use_veteran_model? ? Veteran::Service::Representative : AccreditedIndividual
      end

      # Veteran::Service::Representative specific query methods

      def where_clause_for_veteran_type
        # Map AccreditedIndividual type_param to Veteran::Service::Representative user_types
        veteran_type = case type_param
                       when 'attorney' then 'attorney'
                       when 'claims_agent' then 'claim_agents'
                       when 'representative' then 'veteran_service_officer'
                       else type_param
                       end

        ['? = ANY(veteran_representatives.user_types)', veteran_type]
      end

      def select_query_string_for_veteran
        "veteran_representatives.*, #{distance_query_string_for_veteran}"
      end

      def distance_query_string_for_veteran
        ActiveRecord::Base
          .sanitize_sql_array([
                                'ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, ' \
                                'veteran_representatives.location) as distance',
                                search_params[:long],
                                search_params[:lat]
                              ])
      end

      def sort_query_string_for_veteran
        case sort_param
        when 'first_name_asc' then 'first_name ASC'
        when 'first_name_desc' then 'first_name DESC'
        when 'last_name_asc' then 'last_name ASC'
        when 'last_name_desc' then 'last_name DESC'
        else
          distance_asc_string_for_veteran
        end
      end

      def distance_asc_string_for_veteran
        ActiveRecord::Base.sanitize_sql_for_order(
          [
            Arel.sql(
              'ST_Distance(ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, veteran_representatives.location) ASC'
            ),
            search_params[:long],
            search_params[:lat]
          ]
        )
      end

      def find_veteran_with_name_similar_to(query)
        search_phrase = search_params[:name]
        fuzzy_search_threshold = Veteran::Service::Constants::FUZZY_SEARCH_THRESHOLD

        wrapped_query = Veteran::Service::Representative.from("(#{query.to_sql}) as veteran_representatives")
        wrapped_query.where('word_similarity(?, veteran_representatives.full_name) >= ?',
                            search_phrase,
                            fuzzy_search_threshold)
      end
    end
  end
end
