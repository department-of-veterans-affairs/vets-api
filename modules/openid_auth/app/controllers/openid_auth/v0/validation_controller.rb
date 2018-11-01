# frozen_string_literal: true

require_dependency 'openid_auth/application_controller'

module OpenidAuth
  module V0
    class ValidationController < ApplicationController
      before_action { permit_scopes %w[veteran_status.read] }

      def index
        render json: @current_user, serializer: OpenidAuth::UserSerializer
      rescue StandardError
        raise_error!
      end

      private

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'AUTH_STATUS502',
          source: self.class.to_s
        )
      end
    end
  end
end
