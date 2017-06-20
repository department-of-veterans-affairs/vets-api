# frozen_string_literal: true
module V0
  class Post911GIBillStatusesController < ApplicationController
    def show
      response = service.get_gi_bill_status
      render json: response,
             serializer: Post911GIBillStatusSerializer,
             meta: response.metadata
    end

    private

    def service
      EVSS::GiBillStatus::ServiceFactory.get_service(
        user: @current_user, mock_service: Settings.evss.mock_gi_bill_status
      )
    end
  end
end
