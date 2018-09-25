# frozen_string_literal: true

module VeteranVerification
  module V0
    class ServiceHistoryController < ApplicationController
      before_action { authorize :emis, :access? }

      def index
        response = ServiceHistoryEpisode.for_user(@current_user)

        render json: response, each_serializer: VeteranVerification::ServiceHistorySerializer
      end
    end
  end
end
