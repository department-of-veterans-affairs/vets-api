# frozen_string_literal: true

require 'evss/error_middleware'

module ClaimsApi
  module V0
    class ClaimsController < ClaimsApi::V0::ApplicationController
      def index
        claims = claims_service.all
        render json: claims,
               serializer: ActiveModel::Serializer::CollectionSerializer,
               each_serializer: ClaimsApi::ClaimListSerializer
      rescue EVSS::ErrorMiddleware::EVSSError => e
        log_message_to_sentry('Error in claims v0',
                              :warning,
                              body: e.message)
        raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claims not found')
      end

      def show
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
          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
        end
      rescue => e
        log_message_to_sentry('Error in claims show',
                              :warning,
                              body: e.message)
        raise if e.is_a?(::Common::Exceptions::UnprocessableEntity)

        raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
      end

      private

      def fetch_errored(claim)
        if claim.evss_response&.any?
          errors = format_evss_errors(claim.evss_response['messages'])
          raise ::Common::Exceptions::UnprocessableEntity.new(errors: errors)
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
