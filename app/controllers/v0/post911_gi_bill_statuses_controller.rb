# frozen_string_literal: true
module V0
  class Post911GIBillStatusesController < ApplicationController
    include SentryLogging

    def show
      response = service.get_gi_bill_status
      if response.user_not_found?
        # returns a standardized 404
        raise Common::Exceptions::RecordNotFound, @current_user.email
      elsif response.contains_no_user_info? || !response.ok?
        log_message_to_sentry(
          'Unexpected response from EVSS GiBillStatus Service',
          :warn,
          evss_status: response.status
        )
        render json: { data: nil, meta: response.metadata }
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
