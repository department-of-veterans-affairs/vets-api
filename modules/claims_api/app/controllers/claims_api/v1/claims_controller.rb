# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require_dependency 'claims_api/unsynchronized_evss_claims_service'
require_dependency 'claims_api/concerns/poa_verification'

module ClaimsApi
  module V1
    class ClaimsController < ApplicationController
      include ClaimsApi::PoaVerification
      before_action { permit_scopes %w[claim.read] }

      def index
        claims = service.all
        render json: claims,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      rescue EVSS::ErrorMiddleware::EVSSError => e
        log_message_to_sentry('EVSSError in claims v1',
                              :warning,
                              body: e.message)
        render json: [],
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      end

      def show
        if (pending_claim = ClaimsApi::AutoEstablishedClaim.pending?(params[:id]))
          render json: pending_claim,
                 serializer: ClaimsApi::AutoEstablishedClaimSerializer
        else
          begin
            evss_claim_id = ClaimsApi::AutoEstablishedClaim.evss_id_by_token(params[:id]) || params[:id]
            fetch_and_render_evss_claim(evss_claim_id)
          rescue EVSS::ErrorMiddleware::EVSSError
            render json: { errors: [{ detail: 'Claim not found' }] },
                   status: :not_found
          end
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
    end
  end
end
