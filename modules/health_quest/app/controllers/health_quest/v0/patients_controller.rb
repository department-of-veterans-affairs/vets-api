# frozen_string_literal: true

module HealthQuest
  module V0
    class PatientsController < HealthQuest::V0::BaseController
      def signed_in_patient
        render json: factory.get(current_user.icn).response[:body]
      end

      def create
        render json: factory.create({}).response[:body]
      end

      private

      def factory
        HealthQuest::Resource::Factory.manufacture(
          user: current_user,
          resource_identifier: 'patient',
          api: Settings.hqva_mobile.lighthouse.health_api
        )
      end
    end
  end
end
