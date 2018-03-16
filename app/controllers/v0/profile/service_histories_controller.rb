# frozen_string_literal: true

module V0
  module Profile
    class ServiceHistoriesController < ApplicationController
      before_action { authorize :evss, :access? }

      def show
        response = EMISRedis::MilitaryInformation.for_user(@current_user).service_history

        render json: response, serializer: ServiceHistorySerializer
      end
    end
  end
end
