# frozen_string_literal: true

module Veteran
  module V0
    class FlagAccreditedRepresentativesController < ApplicationController
      service_tag 'lighthouse-veteran'
      before_action :enable_csrf_protection
      before_action :feature_enabled
      skip_before_action :authenticate

      def create
        flags = nil

        begin
          flags = create_flags

          if flags.all?(&:valid?)
            flags.each(&:save!)
            render json: flags, each_serializer: Veteran::FlaggedVeteranRepresentativeContactDataSerializer,
                   status: :created
          else
            raise ActiveRecord::Rollback, 'Invalid flags present'
          end
        rescue ActiveRecord::Rollback
          render json: { errors: flags.map(&:errors).reject(&:empty?) }, status: :unprocessable_entity
        rescue ArgumentError => e
          render json: { errors: { flag_type: [e.message] } }, status: :unprocessable_entity
        end
      end

      private

      def enable_csrf_protection
        set_csrf_header
      end

      def create_flags
        FlaggedVeteranRepresentativeContactData.transaction do
          params[:flags].map do |flag_data|
            FlaggedVeteranRepresentativeContactData.new(
              flag_data.permit(:flag_type, :flagged_value).merge(
                ip_address: request.remote_ip,
                representative_id: params[:representative_id]
              )
            )
          end
        end
      end

      def feature_enabled
        routing_error unless Flipper.enabled?(:find_a_representative_flag_results_enabled)
      end
    end
  end
end
