# frozen_string_literal: true

require 'lighthouse/veterans_health/client'

module Mobile
  module V0
    class ObservationsController < ApplicationController
      def show
        response = client.get_observation(params[:id])
        begin
          observation = Mobile::V0::Adapters::Observation.parse(response.body)
        rescue => e
          PersonalInformationLog.create!(
            data: { observation: response, error: e.message },
            error_class: 'MobileObservationModelValidationError'
          )
        end

        render json: ObservationSerializer.new(observation)
      end

      private

      def client
        @client ||= Lighthouse::VeteransHealth::Client.new(current_user.icn)
      end
    end
  end
end
