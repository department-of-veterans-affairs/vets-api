# frozen_string_literal: true

require 'search_click_tracking/service'

module V0
  class SearchClickTrackingController < ApplicationController
    include ActionView::Helpers::SanitizeHelper

    skip_before_action :authenticate
    skip_before_action :verify_authenticity_token

    # Sends click tracking data to search.gov analytics, based on the passed url, query, position, client_ip, and user_agent.
    #
    def create
      response = SearchClickTracking::Service.new(url, query, position, client_ip, user_agent).track_click
      render nothing: true, status: 204
    end

    private

    def search_params
      params.permit(:url, :query, :position, :client_ip, :user_agent )
    end

    # Returns a sanitized, permitted version of the passed url params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def url
      sanitize search_params['url']
    end
    
    # Returns a sanitized, permitted version of the passed query params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def query
      sanitize search_params['query']
    end
    
    # Returns a sanitized, permitted version of the passed position params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def position
      sanitize search_params['position']
    end
    
    # Returns a sanitized, permitted version of the passed client_ip params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def client_ip
      sanitize search_params['client_ip']
    end

    # Returns a sanitized, permitted version of the passed user_agent params.
    #
    # @return [String]
    # @see https://api.rubyonrails.org/v4.2/classes/ActionView/Helpers/SanitizeHelper.html#method-i-sanitize
    #
    def user_agent
      sanitize search_params['user_agent']
    end

    
  end
end
