# frozen_string_literal: true

module V0
  module GIDS
    class InstitutionProgramsController < GIDSController
      def autocomplete
        render json: service.get_institution_program_autocomplete_suggestions_v0(scrubbed_params)
      end

      def search
        render json: service.get_institution_program_search_results_v0(scrubbed_params)
      end
    end
  end
end
