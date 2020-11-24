# frozen_string_literal: true

# dependencies
require_dependency 'apps_api/application_controller'
require 'okta/directory_service.rb'
module AppsApi
  module V0
    class NotificationController < ApplicationController
      skip_before_action(:authenticate)
      before_action(:check_verification)

      def connect
        return :ok
      end

      def disconnect
        return :ok
      end

      private

      def check_verification
        if request.headers['X-Okta-Verification-Challenge']
          render json: {
            verification: request.headers['X-Okta-Verification-Challenge']
          }
        end
      end
    end
  end
end
