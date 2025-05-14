# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestDecisionsController < ApplicationController
      include PowerOfAttorneyRequests

      before_action do
        authorize PowerOfAttorneyRequestDecision
      end

      with_options only: :create do
        before_action do
          id = params[:power_of_attorney_request_id]
          set_poa_request(id)
        end
      end

      def create
        declination_reason = decision_params[:declination_reason]

        case decision_params[:type]
        when 'acceptance'
          PowerOfAttorneyRequestService::Accept.new(@poa_request, creator).call
          render json: {}, status: :ok
        when 'declination'
          if declination_reason.blank?
            render json: { errors: ["Validation failed: Declination reason can't be blank"] }, status: :bad_request
            return
          end

          @poa_request.mark_declined!(creator, declination_reason)
          send_declination_email(@poa_request)

          Monitoring.new.track_duration('ar.poa.request.duration', from: @poa_request.created_at)
          Monitoring.new.track_duration('ar.poa.request.declined.duration', from: @poa_request.created_at)

          render json: {}, status: :ok
        else
          render json: {
            errors: ['Invalid type parameter - Types accepted: [acceptance declination]']
          }, status: :bad_request
        end
      rescue PowerOfAttorneyRequestService::Accept::Error => e
        render json: { errors: [e.message] }, status: e.status
      rescue ActiveRecord::RecordInvalid => e
        error_message = e.message.sub(/^Validation failed: /, '')
        render json: { errors: [error_message] }, status: :unprocessable_entity
      rescue Faraday::TimeoutError => e
        render json: { errors: ["Gateway Timeout: #{e.message}"] }, status: :gateway_timeout
      rescue Common::Exceptions::ResourceNotFound
        render json: { errors: ['Record not found'] }, status: :not_found
      rescue => e
        render json: { errors: [e.message] }, status: :internal_server_error
      end

      private

      def decision_params
        params.require(:decision).permit(:type, :declination_reason)
      end

      def creator
        current_user.user_account
      end

      def send_declination_email(poa_request)
        notification = poa_request.notifications.create!(type: 'declined')
        PowerOfAttorneyRequestEmailJob.perform_async(
          notification.id
        )
      end
    end
  end
end
