# frozen_string_literal: true

module Veteran
  module V0
    class FlagAccreditedRepresentativesController < ApplicationController
      service_tag 'lighthouse-veteran'
      skip_before_action :verify_authenticity_token
      skip_before_action :authenticate
      before_action :feature_enabled

      def create
        flags = params[:flags].map do |flag_data|
          FlaggedVeteranRepresentativeContactData.new(
            flag_data.permit(:flag_type, :flagged_value).merge(
              ip_address: request.remote_ip,
              representative_id: params[:representative_id]
            )
          )
        end

        saved_flags = flags.select(&:save)

        if saved_flags.length == flags.length
          render json: saved_flags, status: :created
        else
          render json: { errors: flags.map(&:errors).reject(&:empty?) }, status: :unprocessable_entity
        end
      rescue ArgumentError => e
        render json: { errors: { flag_type: [e.message] } }, status: :unprocessable_entity
      end

      private

      def feature_enabled
        routing_error unless Flipper.enabled?(:find_a_representative_enable_api)
      end
    end
  end
end
