# frozen_string_literal: true

require_dependency 'claims_api/application_controller'
require_dependency 'claims_api/concerns/poa_verification'

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
            claim = ClaimsApi::AutoEstablishedClaim.find(params[:id])

            if claim.status == 'errored' && claim.evss_response.any?
              render json: { errors: format_evss_errors(claim.evss_response) },
                     status: :unprocessable_entity
            end
            fetch_and_render_evss_claim(claim.try(:evss_id) || params[:id])
          rescue EVSS::ErrorMiddleware::EVSSError
            render json: { errors: [{ detail: 'Claim not found' }] },
                   status: :not_found
          end
        end
      end

      private

      def fetch_and_render_evss_claim(id)
        claim = claims_service.update_from_remote(id)
        render json: claim, serializer: ClaimsApi::ClaimDetailSerializer
      end
    end
  end
end
