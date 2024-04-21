# frozen_string_literal: true

module ClaimsApi
  module V2
    class PowerOfAttorneyRequestsController < ClaimsApi::V2::ApplicationController
      def index
        poa_requests = ClaimsApi::PowerOfAttorneyRequestService::Search.perform
        render json: Blueprints::PowerOfAttorneyRequestBlueprint.render(poa_requests, root: :data)
      end
    end
  end
end
