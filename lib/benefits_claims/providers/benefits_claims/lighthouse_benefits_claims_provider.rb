# frozen_string_literal: true

require 'benefits_claims/providers/benefits_claims/benefits_claims_provider'
require 'benefits_claims/responses/claim_response'
require 'lighthouse/benefits_claims/service'

module BenefitsClaims
  module Providers
    # Provider implementation for Lighthouse Benefits Claims API
    #
    # Wraps the existing BenefitsClaims::Service and transforms Lighthouse API
    # responses through the ClaimResponse DTO to ensure data consistency and validation.
    #
    # While Lighthouse already returns data in JSON:API format with camelCase attributes,
    # this transformation layer demonstrates the provider pattern for future implementations
    # (e.g., CHAMPVA) that will need to transform their native formats.
    #
    # @example Usage
    #   provider = LighthouseBenefitsClaimsProvider.new(user)
    #   claims = provider.get_claims # Returns transformed claim data
    #   claim = provider.get_claim('123') # Returns transformed single claim
    class LighthouseBenefitsClaimsProvider
      include BenefitsClaimsProvider

      def initialize(user)
        @user = user
        @service = BenefitsClaims::Service.new(user.icn)
      end

      def get_claims
        response = @service.get_claims

        # Transform each claim through the DTO
        response['data'] = response['data'].map { |claim_data| transform_to_dto(claim_data) }

        response
      rescue Common::Exceptions::BaseError => e
        Rails.logger.error(
          'Lighthouse claims retrieval failed',
          {
            error_type: e.class.to_s,
            error_message: e.message
          }
        )
        raise
      end

      def get_claim(id)
        response = @service.get_claim(id)

        # Transform the single claim through the DTO
        response['data'] = transform_to_dto(response['data'])

        response
      rescue Common::Exceptions::BaseError => e
        Rails.logger.error(
          'Lighthouse claim retrieval failed',
          {
            error_type: e.class.to_s,
            error_message: e.message
          }
        )
        raise
      end

      private

      # Transforms Lighthouse claim data through ClaimResponse DTO
      #
      # This method demonstrates the transformation pattern that future providers
      # will need to implement. For Lighthouse, this validates the data structure
      # and ensures consistency.

      def transform_to_dto(claim_data)
        dto = build_claim_response_dto(claim_data)
        serialize_dto_to_json_api(dto)
      end

      def build_claim_response_dto(claim_data)
        BenefitsClaims::Responses::ClaimResponse.new(
          id: claim_data['id'],
          type: claim_data['type'],
          base_end_product_code: claim_data.dig('attributes', 'baseEndProductCode'),
          claim_date: claim_data.dig('attributes', 'claimDate'),
          claim_phase_dates: build_claim_phase_dates(claim_data.dig('attributes', 'claimPhaseDates')),
          claim_type: claim_data.dig('attributes', 'claimType'),
          claim_type_code: claim_data.dig('attributes', 'claimTypeCode'),
          close_date: claim_data.dig('attributes', 'closeDate'),
          decision_letter_sent: claim_data.dig('attributes', 'decisionLetterSent'),
          development_letter_sent: claim_data.dig('attributes', 'developmentLetterSent'),
          documents_needed: claim_data.dig('attributes', 'documentsNeeded'),
          end_product_code: claim_data.dig('attributes', 'endProductCode'),
          evidence_waiver_submitted5103: claim_data.dig('attributes', 'evidenceWaiverSubmitted5103'),
          lighthouse_id: claim_data.dig('attributes', 'lighthouseId'),
          status: claim_data.dig('attributes', 'status'),
          tracked_items: build_tracked_items(claim_data.dig('attributes', 'trackedItems'))
        )
      end

      def build_claim_phase_dates(phase_dates_data)
        return nil if phase_dates_data.nil?

        BenefitsClaims::Responses::ClaimPhaseDates.new(
          phase_change_date: phase_dates_data['phaseChangeDate'],
          phase_type: phase_dates_data['phaseType']
        )
      end

      def build_tracked_items(tracked_items_data)
        return nil if tracked_items_data.nil?
        return [] if tracked_items_data.empty?

        tracked_items_data.map do |item_data|
          BenefitsClaims::Responses::TrackedItem.new(
            display_name: item_data['displayName'],
            status: item_data['status']
          )
        end
      end

      def serialize_dto_to_json_api(dto)
        {
          'id' => dto.id,
          'type' => dto.type,
          'attributes' => serialize_claim_attributes(dto)
        }.with_indifferent_access
      end

      def serialize_claim_attributes(dto)
        attributes = {
          'baseEndProductCode' => dto.base_end_product_code,
          'claimDate' => dto.claim_date,
          'claimType' => dto.claim_type,
          'claimTypeCode' => dto.claim_type_code,
          'closeDate' => dto.close_date,
          'decisionLetterSent' => dto.decision_letter_sent,
          'developmentLetterSent' => dto.development_letter_sent,
          'documentsNeeded' => dto.documents_needed,
          'endProductCode' => dto.end_product_code,
          'evidenceWaiverSubmitted5103' => dto.evidence_waiver_submitted5103,
          'lighthouseId' => dto.lighthouse_id,
          'status' => dto.status
        }

        attributes['claimPhaseDates'] = serialize_phase_dates(dto.claim_phase_dates) if dto.claim_phase_dates

        attributes['trackedItems'] = serialize_tracked_items(dto.tracked_items) if dto.tracked_items

        attributes
      end

      def serialize_phase_dates(phase_dates)
        {
          'phaseChangeDate' => phase_dates.phase_change_date,
          'phaseType' => phase_dates.phase_type
        }.compact
      end

      def serialize_tracked_items(tracked_items)
        tracked_items.map do |item|
          {
            'displayName' => item.display_name,
            'status' => item.status
          }.compact
        end
      end
    end
  end
end
