# frozen_string_literal: true

require_dependency 'mobile/application_controller'

module Mobile
  module V0
    class UsersController < ApplicationController
      AVAILABLE_SERVICES = %w[
        appeals
        appointments
        claims
        directDepositBenefits
        letters
        militaryServiceHistory
        userProfileUpdate
      ].freeze
      
      def show
        render json: Mobile::V0::UserSerializer.new(@current_user, options)
      end
      
      private
      
      def options
        {
          meta: {
            available_services: AVAILABLE_SERVICES
          }
        }
      end
    end
  end
end
