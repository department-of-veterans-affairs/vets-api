# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require_dependency 'claims_api/unsynchronized_evss_claims_service'

module ClaimsApi
  module V0
    class ClaimsController < ApplicationController
      skip_before_action(:authenticate)
      before_action :handle_auto_established_claim
      before_action :verify_power_of_attorney

      def index
        claims = service.all
        render json: claims,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      end

      def show
        fetch_and_render_evss_claim(params[:id])
      end

      private

      def handle_auto_established_claim
        if ClaimsApi::AutoEstablishedClaim.exists?(params[:id])
          auto_established_claim = ClaimsApi::AutoEstablishedClaim.find(params[:id])
          if auto_established_claim.evss_id.nil?
            render json: auto_established_claim,
                   serializer: ClaimsApi::AutoEstablishedClaimSerializer
          else
            fetch_and_render_evss_claim(auto_established_claim.evss_id)
          end
        end
      end

      def fetch_and_render_evss_claim(id)
        claim = service.update_from_remote(id)
        render json: claim, serializer: ClaimsApi::ClaimDetailSerializer
      end

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
