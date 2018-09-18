# frozen_string_literal: true

module V0
  class SearchController < ApplicationController
    include ActionView::Helpers::SanitizeHelper

    skip_before_action :authenticate

    def index
      response = Search::Service.new(query).results

      render json: response, serializer: SearchSerializer
    end

    private

    def search_params
      params.permit(:query)
    end

    # Returns a sanitized, permitted version of the passed query params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def query
      sanitize search_params['query']
    end
  end
end
