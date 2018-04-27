# frozen_string_literal: true

module V0
  class AppealsController < ApplicationController
    include ActionController::Serialization

    before_action { authorize :appeals, :access? }

    def index
      appeals_response = Appeals::Service.new.get_appeals(current_user)
      render(
        json: appeals_response.body
      )
    end
  end
end
