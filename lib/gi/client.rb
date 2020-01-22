# frozen_string_literal: true

module GI
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration GI::Configuration

    def get_institution_autocomplete_suggestions(params = {})
      response = perform(:get, 'institutions/autocomplete', params)
      gids_response(response)
    end

    def get_institution_program_autocomplete_suggestions(params = {})
      response = perform(:get, 'institution_programs/autocomplete', params)
      gids_response(response)
    end

    def get_calculator_constants(params = {})
      response = perform(:get, 'calculator/constants', params)
      gids_response(response)
    end

    def get_institution_search_results(params = {})
      response = perform(:get, 'institutions', params)
      gids_response(response)
    end

    def get_institution_program_search_results(params = {})
      response = perform(:get, 'institution_programs', params)
      gids_response(response)
    end

    def get_institution_details(params = {})
      facility_code = params[:id]
      response = perform(:get, "institutions/#{facility_code}", params.except(:id))
      gids_response(response)
    end

    def get_institution_children(params = {})
      facility_code = params[:id]
      response = perform(:get, "institutions/#{facility_code}/children", params.except(:id))
      gids_response(response)
    end

    def get_zipcode_rate(params = {})
      zipcode = params[:id]
      response = perform(:get, "zipcode_rates/#{zipcode}", {})
      gids_response(response)
    end

    private

    def gids_response(response)
      GI::GIDSResponse.from(response)
    end
  end
end
