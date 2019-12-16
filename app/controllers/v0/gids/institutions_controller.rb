# frozen_string_literal: true

module V0
  module Gids
    class InstitutionsController < GidsController
      def autocomplete
        render json: gi_response_body(:get_institution_autocomplete_suggestions, scrubbed_params)
      end

      def search
        render json: gi_response_body(:get_institution_search_results, scrubbed_params)
      end

      def show
        render json: gi_response_body(:get_institution_details, scrubbed_params)
      end

      def children
        render json: gi_response_body(:get_institution_children, scrubbed_params)
      end
    end
  end
end
