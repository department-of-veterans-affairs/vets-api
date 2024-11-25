# frozen_string_literal: true

require_relative 'client'
require_relative 'search_configuration'

module GI
  # Core class responsible for api interface search operations
  class SearchClient < GI::Client
    configuration GI::SearchConfiguration

    FLIGHT_PROGRAM_TYPE = 'FLGT'

    def get_institution_search_results_v0(params = {})
      response = perform(:get, 'v0/institutions', params)
      gids_response(response)
    end

    def get_institution_program_search_results_v0(params = {})
      # Mock response if querying for flight school programs
      # TO-DO: Remove after flight school program data becomes accessible
      if params[:type] == FLIGHT_PROGRAM_TYPE
        config.instance_variable_set(:@program_type_flight, true)
      end

      response = perform(:get, 'v0/institution_programs', params)
      gids_response(response)
    end

    def get_institution_search_results_v1(params = {})
      response = perform(:get, 'v1/institutions', params)
      gids_response(response)
    end

    def get_institution_program_search_results_v1(params = {})
      response = perform(:get, 'v1/institution_programs', params)
      gids_response(response)
    end
  end
end
