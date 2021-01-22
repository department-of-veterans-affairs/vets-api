# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  class DiscoveryController < ApplicationController
    skip_before_action :authenticate

    def welcome
      render json: { data: { attributes: { message: 'Welcome to the mobile API' } } }
    end

    def index
      render json: Mobile::V0::DiscoverySerializer.new(Mobile::V0::Discovery.new(params))
    end
  end
end
