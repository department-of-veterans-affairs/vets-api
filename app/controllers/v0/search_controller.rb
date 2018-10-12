# frozen_string_literal: true

module V0
  class SearchController < ApplicationController
    include ActionView::Helpers::SanitizeHelper

    skip_before_action :authenticate

    def index
      response = Search::Service.new(query, offset).results

      render json: response, serializer: SearchSerializer
    end

    private

    def search_params
      params.permit(:query, :offset)
    end

    # Returns a sanitized, permitted version of the passed query params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def query
      sanitize search_params['query']
    end

    # The offset defines the number of results you want to skip from the first result.
    # Search.gov's default is 0 and the maximum is 999.
    #
    # Returns a sanitized, permitted version of the passed offset params. If 'offset'
    # is not supplied, it returns nil.
    #
    # @return [String]
    # @return [NilClass]
    # @see https://search.usa.gov/sites/7378/api_instructions
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def offset
      sanitize search_params['offset']
    end
  end
end
