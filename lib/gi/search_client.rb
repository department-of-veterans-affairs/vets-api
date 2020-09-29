# frozen_string_literal: true

require_relative 'client'
require_relative 'search_configuration'

module GI
  # Core class responsible for api interface search operations
  class SearchClient < GI::Client
    configuration GI::SearchConfiguration

    def get_institution_search_results(params = {})
      response = perform(:get, 'institutions', params)
      gids_response(response)
    end

    def get_institution_program_search_results(params = {})
      response = perform(:get, 'institution_programs', params)
      gids_response(response)
    end
  end
end
