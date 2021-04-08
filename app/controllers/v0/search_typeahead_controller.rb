# frozen_string_literal: true

require 'search_typeahead/service'

module V0
  class SearchTypeaheadController < ApplicationController
    include ActionView::Helpers::SanitizeHelper

    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    # gets suggestions list from search.gov after being passed a query, name, and API key
    #
    def index
      response = SearchTypeahead::Service.new(query).suggestions
      render json: response
    end

    private

    def typeahead_params
      params.permit(:query)
    end

    # Returns a sanitized, permitted version of the passed query params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def query
      sanitize typeahead_params['query']
    end
  end
end
