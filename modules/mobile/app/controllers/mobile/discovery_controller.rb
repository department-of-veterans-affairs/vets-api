# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  class DiscoveryController < ApplicationController
    skip_before_action :authenticate

    def index
      # TODO: this will be the endpoint that returns the discovery service map
      # for now it returns a simple welcome message
      render json: { data: { attributes: { message: 'Welcome to the mobile API' } } }
    end
  end
end
