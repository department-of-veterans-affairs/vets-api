# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require_dependency 'claims_api/unsynchronized_evss_claims_service'

module ClaimsApi
  module V0
    class ClaimsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :verify_power_of_attorney

      def index
        claims = service.all
        render json: claims,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      end

      def show
        claim = service.update_from_remote(params[:id])
        render json: claim, serializer: ClaimsApi::ClaimDetailSerializer
      end

      private

      def service
        ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
      end

      def target_veteran
        ClaimsApi::Veteran.from_headers(request.headers)
      end

      def verify_power_of_attorney
        if header('X-Consumer-PoA').present?
          verifier = EVSS::PowerOfAttorneyVerifier.new(target_veteran)
          verifier.verify(header('X-Consumer-PoA'))
        end
      end
    end
  end
end
