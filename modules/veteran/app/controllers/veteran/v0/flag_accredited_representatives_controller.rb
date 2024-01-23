# frozen_string_literal: true

module Veteran
  module V0
    class FlagAccreditedRepresentativesController < ApplicationController
      service_tag 'lighthouse-veteran'
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate
      before_action :feature_enabled
      before_action :flag_params

      def create
        flag = FlaggedVeteranRepresentativeContactData.new(flag_params)

        if flag.save
          render json: flag, status: :created
        else
          render json: { errors: flag.errors }, status: :unprocessable_entity
        end
      rescue ArgumentError => e
        render json: { errors: { flag_type: [e.message] } }, status: :unprocessable_entity
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:find_a_representative_enable_api)
      end

      def flag_params
        params.require(:flag).permit(:ip_address, :representative_id, :flag_type, :flagged_value)
      end
    end
  end
end
