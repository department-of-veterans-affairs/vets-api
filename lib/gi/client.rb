# frozen_string_literal: true
require 'common/client/base'
require 'gi/configuration'

module GI
  # Core class responsible for api interface operations
  class Client < Common::Client::Base
    configuration GI::Configuration

    def get_autocomplete_suggestions(term)
      perform(:get, 'institutions/autocomplete', { term: term }, nil).body
    end

    def get_calculator_constants
      perform(:get, 'calculator/constants', nil, nil).body
    end

    def get_search_results(params)
      perform(:get, 'institutions', params, nil).body
    end

    def get_institution_details(facility_code)
      perform(:get, "institutions/#{facility_code}", nil, nil).body
    end
  end
end
