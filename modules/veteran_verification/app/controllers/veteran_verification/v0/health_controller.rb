# frozen_string_literal: true

module VeteranVerification
  module V0
    # HealthController returns a simple health response
    class HealthController < ApplicationController
      skip_before_action(:authenticate)

      def index
        render json: {
          UP: true
        }
      end
    end
  end
end
