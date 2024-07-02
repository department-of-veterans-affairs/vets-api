# frozen_string_literal: true

module Veteran
  module V0
    class OtherAccreditedRepresentativesController < BaseAccreditedRepresentativesController
      before_action :verify_type

      PERMITTED_TYPE = %w[claim_agents attorney].freeze

      private

      def serializer_class
        Veteran::Accreditation::BaseRepresentativeSerializer
      end

      def representative_query
        query = base_query.select("veteran_representatives.*, #{distance_query_string}").where(
          '? = ANY(user_types) ', search_params[:type]
        )

        search_params[:name] ? find_with_name_similar_to(query) : query
      end

      def find_with_name_similar_to(query)
        search_phrase = search_params[:name]
        fuzzy_search_threshold = Veteran::Service::Constants::FUZZY_SEARCH_THRESHOLD
        query.where('word_similarity(?, full_name) >= ?', search_phrase, fuzzy_search_threshold)
      end

      def verify_type
        unless PERMITTED_TYPE.include?(search_params[:type])
          raise Common::Exceptions::InvalidFieldValue.new('type', search_params[:type])
        end
      end
    end
  end
end
