# frozen_string_literal: true

require 'common/client/base'
require_relative 'configuration'
require_relative 'gids_response'

module GI
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration GI::Configuration

    def get_institution_autocomplete_suggestions_v0(params = {})
      response = perform(:get, 'v0/institutions/autocomplete', params)
      gids_response(response)
    end

    def get_institution_program_autocomplete_suggestions_v0(params = {})
      response = perform(:get, 'v0/institution_programs/autocomplete', params)
      gids_response(response)
    end

    def get_calculator_constants_v0(params = {})
      response = perform(:get, 'v0/calculator/constants', params)
      gids_response(response)
    end

    def get_institution_details_v0(params = {})
      facility_code = params[:id]
      response = perform(:get, "v0/institutions/#{facility_code}", params.except(:id))
      gids_response(response)
    end

    def get_institution_children_v0(params = {})
      facility_code = params[:id]
      response = perform(:get, "v0/institutions/#{facility_code}/children", params.except(:id))
      gids_response(response)
    end

    def get_yellow_ribbon_programs_v0(params = {})
      response = perform(:get, 'v0/yellow_ribbon_programs', params)
      gids_response(response)
    end

    def get_zipcode_rate_v0(params = {})
      zipcode = params[:id]
      response = perform(:get, "v0/zipcode_rates/#{zipcode}", {})
      gids_response(response)
    end

    def get_institution_autocomplete_suggestions_v1(params = {})
      response = perform(:get, 'v1/institutions/autocomplete', params)
      gids_response(response)
    end

    def get_institution_program_autocomplete_suggestions_v1(params = {})
      response = perform(:get, 'v1/institution_programs/autocomplete', params)
      gids_response(response)
    end

    def get_calculator_constants_v1(params = {})
      response = perform(:get, 'v1/calculator/constants', params)
      gids_response(response)
    end

    def get_public_export_v1(params = {})
      id = params[:id]
      perform(:get, "v1/public_exports/#{id}", {})
    end

    def get_institution_details_v1(params = {})
      facility_code = params[:id]
      response = perform(:get, "v1/institutions/#{facility_code}", params.except(:id))
      gids_response(response)
    end

    def get_institution_children_v1(params = {})
      facility_code = params[:id]
      response = perform(:get, "v1/institutions/#{facility_code}/children", params.except(:id))
      gids_response(response)
    end

    def get_yellow_ribbon_programs_v1(params = {})
      response = perform(:get, 'v1/yellow_ribbon_programs', params)
      gids_response(response)
    end

    def get_zipcode_rate_v1(params = {})
      zipcode = params[:id]
      response = perform(:get, "v1/zipcode_rates/#{zipcode}", {})
      gids_response(response)
    end

    private

    def gids_response(response)
      GI::GIDSResponse.from(response)
    end
  end
end
