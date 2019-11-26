# frozen_string_literal: true

module V0
  class SearchController < ApplicationController
    include ActionView::Helpers::SanitizeHelper

    skip_before_action :authenticate

    # Returns a page of search results from the Search.gov API, based on the passed query and page.
    #
    # Pagination schema follows precedent from other controllers that return pagination.
    # For example, the app/controllers/v0/prescriptions_controller.rb.
    #
    def index
      response = Search::Service.new(query, page).results

      render json: response, serializer: SearchSerializer, meta: { pagination: response.pagination }
    end

    private

    def search_params
      params.permit(:query, :page)
    end

    # Returns a sanitized, permitted version of the passed query params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def query
      sanitize search_params['query']
    end

    # This is the page (number) of results the FE is requesting to have returned.
    #
    # Returns a sanitized, permitted version of the passed page params. If 'page'
    # is not supplied, it returns nil.
    #
    # @return [String]
    # @return [NilClass]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def page
      page = 1
      page = search_params['page'] if params[:page]
      raise Common::Exceptions::InvalidPaginationParams if Integer(page) > 99

      sanitize search_params['page']
    end
  end
end
