# frozen_string_literal: true

module VeteranVerification
  module V0
    class VeteranStatusController < ApplicationController
      before_action { authorize :emis, :access? }

      def index
        render json: @current_user, serializer: VeteranVerification::VeteranStatusSerializer
      rescue StandardError
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
