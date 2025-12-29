# frozen_string_literal: true

module AccreditedRepresentativePortal
  module V0
    class PowerOfAttorneyRequestDecisionsController < ApplicationController
      include PowerOfAttorneyRequests
      include AccreditedRepresentativePortal::V0::WithdrawalGuard

      before_action do
        authorize PowerOfAttorneyRequestDecision
      end

      with_options only: :create do
        before_action do
          id = params[:power_of_attorney_request_id]
          set_poa_request(id)
          render_404_if_withdrawn!(@poa_request)
        end
      end

      # rubocop:disable Metrics/MethodLength
      def create
        ar_monitoring.trace('ar.poa.request.decision.create') do |span|
          decision = decision_params[:type]
          span.set_tag('poa_request.poa_code', poa_code)
          span.set_tag('poa_request.decision', decision)

          case decision
          when 'acceptance'
            process_acceptance
          when 'declination'
            process_declination
          else
            render_invalid_type_error
          end
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
      # rubocop:enable Metrics/MethodLength

      private

      def process_acceptance
        PowerOfAttorneyRequestService::Accept.new(
          @poa_request,
          current_user.user_account_uuid,
          current_user.power_of_attorney_holder_memberships
        ).call

        enqueue_send_to_corpdb
        track_decision_durations('accepted')
        render json: {}, status: :ok
      end

      def process_declination
        declination_key = decision_params[:key]

        if declination_key.blank?
          render json: { errors: ["Validation failed: Declination reason can't be blank"] }, status: :bad_request
          return
        end

        @poa_request.mark_declined!(
          current_user.user_account_uuid,
          current_user.power_of_attorney_holder_memberships,
          declination_key
        )

        send_declination_email(@poa_request)
        enqueue_send_to_corpdb
        track_decision_durations('declined')

        render json: {}, status: :ok
      end

      def enqueue_send_to_corpdb
        AccreditedRepresentativePortal::SendPoaToCorpDbJob.perform_async(@poa_request.id)
      end

      def track_decision_durations(decision)
        tags = ["decision:#{decision}", "poa_code:#{poa_code}"]

        ar_monitoring.track_duration(
          'ar.poa.request.duration',
          from: @poa_request.created_at,
          tags:
        )

        ar_monitoring.track_duration(
          "ar.poa.request.#{decision}.duration",
          from: @poa_request.created_at,
          tags:
        )
      end

      def render_invalid_type_error
        render json: {
          errors: ['Invalid type parameter - Types accepted: [acceptance declination]']
        }, status: :bad_request
      end

      def decision_params
        params.require(:decision).permit(:type, :declinationReason, :key)
      end

      def send_declination_email(poa_request)
        notification = poa_request.notifications.create!(type: 'declined')
        PowerOfAttorneyRequestEmailJob.perform_async(
          notification.id
        )
      end

      def poa_code
        @poa_request.power_of_attorney_holder_poa_code
      end

      def ar_monitoring
        @ar_monitoring ||= AccreditedRepresentativePortal::Monitoring.new(
          AccreditedRepresentativePortal::Monitoring::NAME,
          default_tags: [
            "controller:#{controller_name}",
            "action:#{action_name}"
          ].compact
        )
      end
    end
  end
end
