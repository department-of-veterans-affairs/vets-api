# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require_dependency 'claims_api/concerns/poa_verification'
require 'evss/error_middleware'

module ClaimsApi
  module V1
    class ClaimsController < ApplicationController
      include ClaimsApi::PoaVerification
      before_action { permit_scopes %w[claim.read] }

      def index
        claims = claims_service.all
        render json: claims,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      rescue => e
        log_message_to_sentry('Error in claims v1',
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
