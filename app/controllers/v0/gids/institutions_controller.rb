# frozen_string_literal: true

module V0
  module GIDS
    class InstitutionsController < GIDSController
      def autocomplete
        render json: service.get_institution_autocomplete_suggestions(scrubbed_params)
      end

      def search
        render json: service.get_institution_search_results(scrubbed_params)
      end

      def show
        render json: service.get_institution_details(scrubbed_params)
      end

      def children
        render json: service.get_institution_children(scrubbed_params)
      end
    end
  end
end
