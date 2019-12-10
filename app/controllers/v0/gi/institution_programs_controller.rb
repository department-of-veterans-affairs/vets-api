# frozen_string_literal: true

module V0
  module GI
    class InstitutionProgramsController < GIController
      def autocomplete
        render json: gi_response_body(:get_institution_program_autocomplete_suggestions, scrubbed_params)
      end

      def search
        render json: gi_response_body(:get_institution_program_search_results, scrubbed_params)
      end
    end
  end
end
