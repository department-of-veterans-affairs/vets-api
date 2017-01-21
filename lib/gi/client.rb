# frozen_string_literal: true
require 'common/client/base'
require 'gi/configuration'

module Gi
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration Gi::Configuration

    def get_autocomplete_suggestions(term)
      json_hash = perform(:get, 'institutions/autocomplete', {term: term}, nil).body
    end

    def get_calculator_constants
      json_hash = perform(:get, 'calculator/constants', nil, nil).body
    end

    def get_search_results(params)
      json_hash = perform(:get, 'institutions', params, nil).body
    end

    def get_institution_details(facility_code)
      json_hash = perform(:get, "institutions/#{facility_code}", nil, nil).body
    end
  end
end
