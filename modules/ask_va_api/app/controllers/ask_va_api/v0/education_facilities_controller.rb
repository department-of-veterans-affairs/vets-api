# frozen_string_literal: true

module AskVAApi
  module V0
    class EducationFacilitiesController < GIDSController
      def autocomplete
        render json: service.get_institution_autocomplete_suggestions_v0(scrubbed_params)
      end

      def search
        render json: service.get_institution_search_results_v0(scrubbed_params)
      end

      def show
        render json: service.get_institution_details_v0(scrubbed_params)
      end

      def children
        render json: service.get_institution_children_v0(scrubbed_params)
      end
    end
  end
end
