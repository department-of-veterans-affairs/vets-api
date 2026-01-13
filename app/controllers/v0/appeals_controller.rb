# frozen_string_literal: true

module V0
  class AppealsController < AppealsBaseController
    service_tag 'appeal-status'
    before_action { authorize :appeals, :access? }

    def index
      appeals_response = appeals_service.get_appeals(current_user)
      render json: appeals_response.body
    end
  end
end
