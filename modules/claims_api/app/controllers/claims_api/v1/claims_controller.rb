# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require_dependency 'claims_api/unsynchronized_evss_claims_service'

module ClaimsApi
  module V1
    class ClaimsController < ApplicationController
      before_action { permit_scopes %w[claim.read] }
      skip_before_action(:authenticate, only: [:healthcheck])
      skip_before_action(:verify_mvi, only: [:healthcheck])
      skip_before_action(:log_request, only: [:healthcheck])

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

      def healthcheck
        if ClaimsApi::EVSSClaim.services_are_healthy?
          render json: ClaimsApi::EVSSClaim.healthy_service_response
        else
          render json: ClaimsApi::EVSSClaim.unhealthy_service_response,
                 status: :service_unavailable
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
