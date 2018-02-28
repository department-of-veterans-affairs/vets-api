# frozen_string_literal: true

require 'appeals_status/service'

module V0
  class AppealsController < ApplicationController
    include ActionController::Serialization

    before_action { authorize :appeals, :access? }

    def index
      resource = AppealsStatus::Service.new.get_appeals(current_user)
      render(
        json: resource.appeals,
        serializer: CollectionSerializer,
        each_serializer: AppealSerializer
      )
    end

    def index_v2
      appeals_response = Appeals::Service.new.get_appeals(current_user)
      render(
        json: appeals_response.body
      )
    end
  end
end
