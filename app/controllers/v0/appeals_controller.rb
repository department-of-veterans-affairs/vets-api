# frozen_string_literal: true

require 'appeals_status/service'

module V0
  class AppealsController < ApplicationController
    include ActionController::Serialization
    before_action :raise_access_denied_if_user_not_loa3

    def index
      resource = AppealsStatus::Service.new.get_appeals(current_user)
      render(
        json: resource.appeals,
        serializer: CollectionSerializer,
        each_serializer: AppealSerializer
      )
    end

    # This should be only LOA3 users, but SSN is available to LOA1, so additional check here
    def raise_access_denied_if_user_not_loa3
      return if current_user.loa3?
      raise Common::Exceptions::Forbidden, detail: 'You do not have access to appeals'
    end
  end
end
