# frozen_string_literal: true

module TravelPay
  class ClaimsController < ApplicationController
    def index
      render json: {
               data: {
                 impacts: {
                   velocity: 'Integrate more quickly once the new API is ready',
                   viability: 'Validate our architecture and system design',
                   onboarding: 'Allow team members to onboard more quickly'
                 }
               }
             },
             status: 418
    end
  end
end
