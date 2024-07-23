# frozen_string_literal: true

module Mobile
  class DiscoveryController < ApplicationController
    skip_before_action :authenticate

    def welcome
      routes = Mobile::Engine.app.routes.routes
      endpoints = routes.collect { |r| "mobile#{r.path.spec.to_s[0...-10]}" }
      render json: {
        data:
          {
            type: 'welcome',
            id: 'welcome',
            attributes:
              {
                message: 'Welcome to the mobile API.',
                endpoints:
              }
          }
      }
    end
  end
end
