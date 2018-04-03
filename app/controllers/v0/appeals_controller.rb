# frozen_string_literal: true

module V0
  class AppealsController < ApplicationController
    before_action { authorize :appeals, :access? }

    def index
      appeals_response = Appeals::Service.new.get_appeals(current_user)
      render(
        json: JSONAPI::Serializer.serialize(appeals_response.appeal_series, is_collection: true)
      )
    end
  end
end
