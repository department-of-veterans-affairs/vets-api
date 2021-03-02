# frozen_string_literal: true

module HealthQuest
  module V0
    class LocationsController < HealthQuest::V0::BaseController
      def index
        render json: factory.search(request.query_parameters).response[:body]
      end

      private

      def factory
        @factory =
          HealthQuest::HealthApi::Location::Factory.manufacture(current_user)
      end
    end
  end
end
