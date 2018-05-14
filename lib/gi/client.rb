# frozen_string_literal: true

require 'common/client/base'
require 'gi/configuration'

module GI
  # Core class responsible for api interface operations
  class ServiceException < Common::Exceptions::BackendServiceException; end
  class Client < Common::Client::Base
    configuration GI::Configuration

    def get_autocomplete_suggestions(params = {})
      perform(:get, 'institutions/autocomplete', params, nil).body
    end

    def get_calculator_constants(params = {})
      perform(:get, 'calculator/constants', params, nil).body
    end

    def get_search_results(params = {})
      perform(:get, 'institutions', params, nil).body
    end

    def get_institution_details(params = {})
      facility_code = params[:id]
      perform(:get, "institutions/#{facility_code}", params.except(:id), nil).body
    end
  end
end
