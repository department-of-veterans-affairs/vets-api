# frozen_string_literal: true

require 'evss/error_middleware'
require 'claims_api/evss_bgs_mapper'

module ClaimsApi
  module V1
    class ClaimsController < ApplicationController
      include ClaimsApi::PoaVerification
      before_action { permit_scopes %w[claim.read] }
      before_action :verify_power_of_attorney!, if: :header_request?

      def index
        claims = claims_status_service.all(target_veteran.participant_id)
        raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claims not found') if claims == []

        render json: claims,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      rescue EVSS::ErrorMiddleware::EVSSError => e
        log_message_to_sentry('Error in claims v1',
                              :warning,
                              body: e.message)
        raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claims not found')
      end

      def show # rubocop:disable Metrics/MethodLength
        claim = ClaimsApi::AutoEstablishedClaim.find_by(id: params[:id])

        if claim && claim.status == 'errored'
          fetch_errored(claim)
        elsif claim && claim.evss_id.blank?
          render json: claim, serializer: ClaimsApi::AutoEstablishedClaimSerializer
        elsif claim && claim.evss_id.present?
          updated_claim = claims_status_service.update_from_remote(claim.evss_id)
          render json: updated_claim, serializer: ClaimsApi::ClaimDetailSerializer, uuid: claim.id
        elsif /^\d{2,20}$/.match?(params[:id])
          claim = claims_status_service.update_from_remote(params[:id])
          # NOTE: source doesn't seem to be accessible within a remote evss_claim
          render json: claim, serializer: ClaimsApi::ClaimDetailSerializer
        else
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
        end
      rescue => e
        unless e.is_a?(::Common::Exceptions::ResourceNotFound)
          log_message_to_sentry('Error in claims show',
                                :warning,
                                body: e.message)
        end
        raise if e.is_a?(::Common::Exceptions::UnprocessableEntity)

        raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
      end

      private

      def fetch_errored(claim)
        if claim.evss_response&.any?
          errors = format_evss_errors(claim.evss_response)
          raise ::Common::Exceptions::UnprocessableEntity.new(errors:)
        else
          message = 'Unknown EVSS Async Error'
          raise ::Common::Exceptions::UnprocessableEntity.new(detail: message)
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
