# frozen_string_literal: true

require 'common/client/base'
require 'gi/configuration'

module GI
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration GI::Configuration

    def get_institution_autocomplete_suggestions(params = {})
      perform(:get, 'institutions/autocomplete', params, nil).body
    end
    
    def get_institution_program_autocomplete_suggestions(params = {})
      perform(:get, 'institution_programs/autocomplete', params, nil).body
    end

    def get_calculator_constants(params = {})
      perform(:get, 'calculator/constants', params, nil).body
    end

    def get_institution_search_results(params = {})
      perform(:get, 'institutions', params, nil).body
    end

    def get_institution_program_search_results(params = {})
      perform(:get, 'institution_programs', params, nil).body
    end

    def get_institution_details(params = {})
      facility_code = params[:id]
      perform(:get, "institutions/#{facility_code}", params.except(:id), nil).body
    end

    def get_institution_children(params = {})
      facility_code = params[:id]
      perform(:get, "institutions/#{facility_code}/children", params.except(:id), nil).body
    end

    def get_zipcode_rate(params = {})
      zipcode = params[:id]
      perform(:get, "zipcode_rates/#{zipcode}", {}, nil).body
    end
  end
end
