# frozen_string_literal: true

require 'search_click_tracking/service'

module V0
  class SearchClickTrackingController < ApplicationController
    include ActionView::Helpers::SanitizeHelper

    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    # Sends click tracking data to search.gov analytics, based on the passed url,
    # query, position, client_ip, and user_agent.
    #
    def create
      response = SearchClickTracking::Service.new(url, query, position, user_agent, module_code).track_click
      if response.success?
        render nothing: true, status: :no_content
      else
        render json: response.body, status: :bad_request
      end
    end

    private

    def click_params
      params.permit(:url, :query, :position, :module_code, :user_agent)
    end

    # Returns a sanitized, permitted version of the passed url params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def url
      sanitize click_params['url']
    end

    # Returns a sanitized, permitted version of the passed query params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def query
      sanitize click_params['query']
    end

    # Returns a sanitized, permitted version of the passed position params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def position
      sanitize click_params['position']
    end

    # Returns a sanitized, permitted version of the passed module_code params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def module_code
      sanitize click_params['module_code']
    end

    # Returns a sanitized, permitted version of the passed user_agent params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def user_agent
      sanitize click_params['user_agent']
    end
  end
end
