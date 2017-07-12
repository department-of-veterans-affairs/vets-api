# frozen_string_literal: true
module V0
  class Post911GIBillStatusesController < ApplicationController
    include SentryLogging

    def show
      response = service.get_gi_bill_status
      if !response.ok?
        log_message_to_sentry(
          'Unexpected response from EVSS GiBillStatus Service',
          :error,
          evss_status: response.status, evss_body: response.body
        )
        render json: { data: nil, meta: response.metadata }
      elsif response.empty?
        # returns a standardized 404
        raise Common::Exceptions::RecordNotFound, @current_user.email
      else
        render json: response,
               serializer: Post911GIBillStatusSerializer,
               meta: response.metadata
      end
    end

    private

    def service
      EVSS::GiBillStatus::ServiceFactory.get_service(
        user: @current_user, mock_service: Settings.evss.mock_gi_bill_status
      )
    end
  end
end
