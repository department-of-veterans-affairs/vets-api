# frozen_string_literal: true
require 'appeals_status/service'

module V0
  class AppealsController < ApplicationController
    include ActionController::Serialization

    def index
      resource = AppealsStatus::Service.new.get_appeals(current_user)
      render(
        json: resource.appeals,
        serializer: CollectionSerializer,
        each_serializer: AppealSerializer
      )
    end
  end
end
