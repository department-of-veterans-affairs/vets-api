# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require 'evss/error_middleware'

module ClaimsApi
  module V0
    class ClaimsController < ApplicationController
      skip_before_action(:authenticate)

      def index
        claims = claims_service.all
        render json: claims,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      rescue => e
        log_message_to_sentry('Error in claims v0',
                              :warning,
                              body: e.message)
        render json: { errors: [{ status: 404, detail: 'Claims not found' }] },
               status: :not_found
      end

      def show
        super
      end
    end
  end
end
