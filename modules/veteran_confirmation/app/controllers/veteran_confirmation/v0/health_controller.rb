# frozen_string_literal: true

require_dependency 'veteran_confirmation/application_controller'

module VeteranConfirmation
  module V0
    # HealthController returns a JSON payload confirmation that the Veteran Confirmation application is
    # properly up and running.
    class HealthController < ApplicationController
      def index
        render json: {
          UP: true
        }
      end
    end
  end
end
