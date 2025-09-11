# frozen_string_literal: true

module CheckIn
  module V1
    class TravelClaimsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[create]
      after_action :after_logger, only: %i[create]
      before_action :authorize_travel_reimbursement

      def create
        start_time = Time.current

        check_in_session = CheckIn::V2::Session.build(
          data: { uuid: permitted_params[:uuid] },
          jwt: low_auth_token
        )

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized
          return
        end

        submit_travel_claim(check_in_session)
      ensure
        log_request_duration(start_time)
      end

      def permitted_params
        params.require(:travel_claims).permit(:uuid, :appointment_date, :facility_type, :time_to_complete)
      end

      private

      def authorize_travel_reimbursement
        routing_error unless Flipper.enabled?('check_in_experience_travel_reimbursement')
      end

      def submit_travel_claim(check_in_session)
        result = TravelClaim::ClaimSubmissionService.new(
          check_in: check_in_session,
          appointment_date: permitted_params[:appointment_date],
          facility_type: permitted_params[:facility_type],
          uuid: permitted_params[:uuid]
        ).submit_claim

        render json: result, status: :ok
      end

      def log_request_duration(start_time)
        return unless start_time

        duration_ms = ((Time.current - start_time) * 1000).round
        facility_type = permitted_params[:facility_type]

        if facility_type == 'vamc'
          StatsD.measure('api.check_in.travel_claim.request.duration', duration_ms)
        else
          StatsD.measure('api.oracle_health.travel_claim.request.duration', duration_ms)
        end
      end
    end
  end
end
