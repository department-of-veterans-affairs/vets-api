# frozen_string_literal: true

require_dependency 'veteran_verification/application_controller'

module VeteranVerification
  module V0
    class ServiceHistoryController < ApplicationController
      before_action { authorize :emis, :access? }
      before_action { permit_scopes %w[service_history.read] }

      def index
        response = ServiceHistoryEpisode.for_user(@current_user)

        render json: response, each_serializer: VeteranVerification::ServiceHistorySerializer
      end
    end
  end
end
