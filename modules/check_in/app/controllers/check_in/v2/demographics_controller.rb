# frozen_string_literal: true

module CheckIn
  module V2
    class DemographicsController < CheckIn::ApplicationController
      before_action :before_logger, only: %i[update], if: :additional_logging?
      after_action :after_logger, only: %i[update], if: :additional_logging?

      def update
        check_in_session = CheckIn::V2::Session.build(data: { uuid: params[:id] }, jwt: low_auth_token)

        unless check_in_session.authorized?
          render json: check_in_session.unauthorized_message, status: :unauthorized and return
        end

        resp = ::V2::Chip::Service.build(check_in: check_in_session,
                                         params: permitted_params[:demographic_confirmations])
                                  .confirm_demographics
        render json: resp, status: resp[:status]
      end

      def permitted_params
        params.require(:demographics)
              .permit(demographic_confirmations: %i[demographics_up_to_date next_of_kin_up_to_date
                                                    emergency_contact_up_to_date])
      end
    end
  end
end
