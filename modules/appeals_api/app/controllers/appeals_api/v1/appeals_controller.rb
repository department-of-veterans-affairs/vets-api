# frozen_string_literal: true

module AppealsApi
  module V1
    class AppealsController < AppealsApi::V0::AppealsController
      include AppealsApi::OpenidAuth

      OAUTH_SCOPES = {
        GET: %w[veteran/AppealsStatus.read representative/AppealsStatus.read system/AppealsStatus.read]
      }.freeze

      private

      def token_validation_api_key
        Settings.dig(:modules_appeals_api, :token_validation, :appeals_status, :api_key)
      end
    end
  end
end
