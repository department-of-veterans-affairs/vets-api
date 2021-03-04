# frozen_string_literal: true

module HealthQuest
  module V0
    class PatientsController < HealthQuest::V0::BaseController
      def signed_in_patient
        render json: factory.get.response[:body]
      end

      def create
        render json: factory.create.response[:body]
      end

      private

      def factory
        @factory ||= HealthApi::Patient::Factory.manufacture(current_user)
      end
    end
  end
end
