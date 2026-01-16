# frozen_string_literal: true

module V0
  class AppealsController < AppealsBaseController
    service_tag 'appeal-status'

    def index
      appeals_response = appeals_service.get_appeals(current_user)
      if Flipper.enabled?(:appeals_response_status)
        render json: appeals_response.body, status: appeals_response.status
      else
        render json: appeals_response.body
      end
    end
  end
end
