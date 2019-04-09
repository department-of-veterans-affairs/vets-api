# frozen_string_literal: true

module V0
  module GI
    class InstitutionsController < GIController
      def autocomplete
        render json: client.get_autocomplete_suggestions(scrubbed_params)
      end

      def search
        render json: client.get_search_results(scrubbed_params)
      end

      def show
        render json: client.get_institution_details(scrubbed_params)
      end
    end
  end
end
