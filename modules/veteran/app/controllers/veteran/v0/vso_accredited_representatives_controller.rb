# frozen_string_literal: true

module Veteran
  module V0
    class VSOAccreditedRepresentativesController < BaseAccreditedRepresentativesController
      before_action :verify_type

      PERMITTED_TYPE = 'veteran_service_officer'

      private

      def serializer_class
        Veteran::Accreditation::VSORepresentativeSerializer
      end

      def representative_query
        query = base_query
                .joins('JOIN LATERAL UNNEST(veteran_representatives.poa_codes) AS UnnestedPoaCode ON true')
                .joins('JOIN veteran_organizations ON UnnestedPoaCode = veteran_organizations.poa')
                .select("veteran_representatives.*, array_agg(veteran_organizations.name ORDER BY veteran_organizations.name) AS organization_names, #{distance_query_string}") # rubocop:disable Layout/LineLength
                .where('? = ANY(veteran_representatives.user_types)', search_params[:type])
                .group(Veteran::Service::Representative.column_names.map { |col| "veteran_representatives.#{col}" })

        search_params[:name] ? find_with_name_similar_to(query) : query
      end

      def find_with_name_similar_to(query)
        search_phrase = search_params[:name]
        fuzzy_search_threshold = Veteran::Service::Constants::FUZZY_SEARCH_THRESHOLD

        wrapped_query = Veteran::Service::Representative.from("(#{query.to_sql}) as veteran_representatives")
        wrapped_query.where('word_similarity(?, veteran_representatives.full_name) >= ?', search_phrase,
                            fuzzy_search_threshold)
      end

      def verify_type
        unless search_params[:type] == PERMITTED_TYPE
          raise Common::Exceptions::InvalidFieldValue.new('type', search_params[:type])
        end
      end
    end
  end
end
