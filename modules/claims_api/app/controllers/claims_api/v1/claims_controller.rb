# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require_dependency 'claims_api/unsynchronized_evss_claims_service'

module ClaimsApi
  module V1
    class ClaimsController < ApplicationController
      before_action { permit_scopes %w[claim.read] }
      before_action :verify_power_of_attorney, if: :poa_request?

      def index
        claims = service.all
        render json: claims,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      end

      def show
        if (pending_claim = ClaimsApi::AutoEstablishedClaim.pending?(params[:id]))
          render json: pending_claim,
                 serializer: ClaimsApi::AutoEstablishedClaimSerializer
        else
          evss_claim_id = ClaimsApi::AutoEstablishedClaim.evss_id_by_token(params[:id]) || params[:id]
          fetch_and_render_evss_claim(evss_claim_id)
        end
      end

      private

      def fetch_and_render_evss_claim(id)
        claim = service.update_from_remote(id)
        render json: claim, serializer: ClaimsApi::ClaimDetailSerializer
      end

      def service
        ClaimsApi::UnsynchronizedEVSSClaimService.new(target_veteran)
      end

      def target_veteran
        if poa_request?
          ClaimsApi::Veteran.from_headers(request.headers)
        else
          ClaimsApi::Veteran.from_identity(identity: @current_user)
        end
      end

      def verify_power_of_attorney
        verifier = EVSS::PowerOfAttorneyVerifier.new(target_veteran)
        verifier.verify(@current_user)
      end

      def poa_request?
        # if any of the required headers are present we should attempt to use headers
        headers_to_check = ['HTTP_X_VA_SSN', 'HTTP_X_VA_Consumer-Username', 'HTTP_X_VA_Birth_Date']
        (request.headers.to_h.keys & headers_to_check).length.positive?
      end
    end
  end
end
