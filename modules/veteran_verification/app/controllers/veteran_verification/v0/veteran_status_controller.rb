# frozen_string_literal: true

require_dependency 'veteran_verification/application_controller'
require 'common/exceptions'

module VeteranVerification
  module V0
    class VeteranStatusController < ApplicationController
      before_action { authorize :emis, :access? }
      before_action { permit_scopes %w[veteran_status.read] }

      def index
        render json: @current_user, serializer: VeteranVerification::VeteranStatusSerializer
      rescue
        raise_error!
      end

      private

      def raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'EMIS_STATUS502',
          source: self.class.to_s
        )
      end
    end
  end
end
