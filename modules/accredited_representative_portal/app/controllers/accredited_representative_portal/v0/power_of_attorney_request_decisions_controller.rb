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
        case decision_params[:type]
        when 'acceptance'
          process_acceptance
        when 'declination'
          process_declination
        else
          render_invalid_type_error
        end
      rescue => e
        handle_create_error(e)
      end

      private

      def handle_create_error(error)
        if @poa_request.present? && Flipper.enabled?(:ar_poa_request_failure_notification_email)
          send_failure_notification_email(@poa_request)
        end

        case error
        when PowerOfAttorneyRequestService::Accept::Error
          render json: { errors: [error.message] }, status: error.status
        when ActiveRecord::RecordInvalid
          error_message = error.message.sub(/^Validation failed: /, '')
          render json: { errors: [error_message] }, status: :unprocessable_entity
        when Faraday::TimeoutError
          render json: { errors: ["Gateway Timeout: #{error.message}"] }, status: :gateway_timeout
        when Common::Exceptions::ResourceNotFound
          render json: { errors: ['Record not found'] }, status: :not_found
        else
          Rails.logger.error "Unhandled error in create action (handled by case statement): #{error.class}" \
                             " - #{error.message}\n#{error.backtrace.join("\n")}"
          render json: { errors: ['An unexpected error occurred. Please try again later.'] },
                 status: :internal_server_error
        end
      end

      def process_acceptance
        PowerOfAttorneyRequestService::Accept.new(@poa_request, creator).call
        render json: {}, status: :ok
      end

      def process_declination
        declination_reason = decision_params[:declination_reason]

        if declination_reason.blank?
          render json: { errors: ["Validation failed: Declination reason can't be blank"] }, status: :bad_request
          return
        end

        @poa_request.mark_declined!(creator, declination_reason)
        send_declination_email(@poa_request)
        track_declination_metrics

        render json: {}, status: :ok
      end

      def track_declination_metrics
        Monitoring.new.track_duration('ar.poa.request.duration', from: @poa_request.created_at)
        Monitoring.new.track_duration('ar.poa.request.declined.duration', from: @poa_request.created_at)
      end

      def render_invalid_type_error
        render json: {
          errors: ['Invalid type parameter - Types accepted: [acceptance declination]']
        }, status: :bad_request
      end

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

      def send_failure_notification_email(poa_request)
        return unless Flipper.enabled?(:ar_poa_request_failure_notification_email)

        notification = poa_request.notifications.create!(type: 'failed')
        PowerOfAttorneyRequestEmailJob.perform_async(
          notification.id
        )
      end
    end
  end
end
