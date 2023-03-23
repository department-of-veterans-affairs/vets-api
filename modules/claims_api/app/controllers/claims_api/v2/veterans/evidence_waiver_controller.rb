# frozen_string_literal: true

require 'bgs'
require 'token_validation/v2/client'
require 'claims_api/claim_logger'

module ClaimsApi
  module V2
    module Veterans
      class EvidenceWaiverController < ClaimsApi::V2::ApplicationController
        before_action :verify_access!

        def submit
          lighthouse_claim = find_lighthouse_claim!(claim_id: params[:id])
          benefit_claim_id = lighthouse_claim.present? ? lighthouse_claim.evss_id : params[:id]
          bgs_claim = find_bgs_claim!(claim_id: benefit_claim_id)

          if lighthouse_claim.blank? && bgs_claim.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          ews = create_ews(params[:id])
          ClaimsApi::EvidenceWaiverBuilderJob.perform_async(ews.id)

          render json: { success: true }
        end

        private

        def create_ews(claim_id)
          attributes = {
            status: ClaimsApi::EvidenceWaiverSubmission::PENDING,
            auth_headers:,
            cid: source_cid,
            claim_id:
          }

          new_ews = ClaimsApi::EvidenceWaiverSubmission.create!(attributes)
          new_ews.save
          new_ews
        end

        def source_cid
          return if token.nil?

          token.payload['cid']
        end

        def find_lighthouse_claim!(claim_id:)
          lighthouse_claim = ClaimsApi::AutoEstablishedClaim.get_by_id_and_icn(claim_id, target_veteran.mpi.icn)

          if looking_for_lighthouse_claim?(claim_id:) && lighthouse_claim.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          lighthouse_claim
        end

        def looking_for_lighthouse_claim?(claim_id:)
          claim_id.to_s.include?('-')
        end

        def find_bgs_claim!(claim_id:)
          return if claim_id.blank?

          bgs_service.ebenefits_benefit_claims_status.find_benefit_claim_details_by_benefit_claim_id(
            benefit_claim_id: claim_id
          )
        rescue Savon::SOAPFault => e
          # the ebenefits service raises an exception if a claim is not found,
          # so catch the exception here and return a 404 instead
          if e.message.include?("No BnftClaim found for #{claim_id}") || e.message.include?("The object [#{claim_id}]")
            raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found')
          end

          raise
        end
      end
    end
  end
end
