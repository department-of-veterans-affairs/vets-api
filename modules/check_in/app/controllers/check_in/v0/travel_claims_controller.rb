# frozen_string_literal: true

module CheckIn
  module V0
    class TravelClaimsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[create]
      after_action :after_logger, only: %i[create]

      def create
        check_in_session = CheckIn::V2::Session.build(data: { uuid: permitted_params[:uuid] }, jwt: low_auth_token)

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized and return
        end

        TravelClaimSubmissionJob.perform_async(permitted_params[:uuid], permitted_params[:appointment_date])

        logger.info({ message: 'Submitted travel claim to background worker' }.merge(permitted_params))

        render nothing: true, status: :accepted
      end

      def permitted_params
        params.require(:travel_claims).permit(:uuid, :appointment_date, :facility_type, :time_to_complete)
      end

      def authorize
        routing_error unless Flipper.enabled?('check_in_experience_travel_reimbursement')
      end
    end
  end
end
