# frozen_string_literal: true

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
      rescue EVSS::ErrorMiddleware::EVSSError => e
        log_message_to_sentry('Error in claims v1',
                              :warning,
                              body: e.message)
        render json: { errors: [{ status: 404, detail: 'Claims not found' }] },
               status: :not_found
      end

      def show # rubocop:disable Metrics/MethodLength
        claim = ClaimsApi::AutoEstablishedClaim.find_by(id: params[:id], source: source_name)

        if claim && claim.status == 'errored'
          fetch_errored(claim)
        elsif claim && claim.evss_id.blank?
          render json: claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        elsif claim && claim.evss_id.present?
          evss_claim = claims_service.update_from_remote(claim.evss_id)
          render json: evss_claim, serializer: ClaimsApi::ClaimDetailSerializer, uuid: claim.id
        elsif /^\d{2,20}$/.match?(params[:id])
          evss_claim = claims_service.update_from_remote(params[:id])
          # NOTE: source doesn't seem to be accessible within a remote evss_claim
          render json: evss_claim, serializer: ClaimsApi::ClaimDetailSerializer
        else
          render json: { errors: [{ status: 404, detail: 'Claim not found' }] },
                 status: :not_found
        end
      rescue => e
        log_message_to_sentry('Error in claims show',
                              :warning,
                              body: e.message)
        render json: { errors: [{ status: 404, detail: 'Claim not found' }] },
               status: :not_found
      end

      private

      def fetch_errored(claim)
        if claim.evss_response&.any?
          render json: { errors: format_evss_errors(claim.evss_response['messages']) },
                 status: :unprocessable_entity
        else
          render json: { errors: [{ status: 422, detail: 'Unknown EVSS Async Error' }] },
                 status: :unprocessable_entity
        end
      end

      def format_evss_errors(errors)
        errors.map do |error|
          formatted = error['key'] ? error['key'].gsub('.', '/') : error['key']
          { status: 422, detail: "#{error['severity']} #{error['detail'] || error['text']}".squish, source: formatted }
        end
      end
    end
  end
end
