# frozen_string_literal: true

require 'search/service'
require 'search_gsa/service'

module V0
  class SearchController < ApplicationController
    include ActionView::Helpers::SanitizeHelper
    service_tag 'search'

    skip_before_action :authenticate

    # Returns a page of search results from the Search.gov API, based on the passed query and page.
    #
    # Pagination schema follows precedent from other controllers that return pagination.
    # For example, the app/controllers/v0/prescriptions_controller.rb.
    #
    def index
      response = search_service.results
      options = { meta: { pagination: response.pagination } }

      render json: SearchSerializer.new(response, options)
    end

    private

    def search_params
      params.permit(:query, :page)
    end

    def search_service
      @search_service ||= if Flipper.enabled?(:search_use_v2_gsa)
                            SearchGsa::Service.new(query, page)
                          else
                            Search::Service.new(query, page)
                          end
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
      sanitize search_params['page']
    end
  end
end
