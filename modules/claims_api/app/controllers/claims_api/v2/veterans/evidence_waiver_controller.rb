# frozen_string_literal: true

require 'bgs'
require 'token_validation/v2/client'
require 'claims_api/claim_logger'
require 'claims_api/dependent_service'

module ClaimsApi
  module V2
    module Veterans
      class EvidenceWaiverController < ClaimsApi::V2::ApplicationController
        def submit
          lighthouse_claim = find_lighthouse_claim!(claim_id: params[:id])
          benefit_claim_id = lighthouse_claim.present? ? lighthouse_claim.evss_id : params[:id]
          bgs_claim = find_bgs_claim!(claim_id: benefit_claim_id)

          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found') if bgs_claim.blank?

          if dependent_service(bgs_claim).dependent_type_claim? && params[:sponsorIcn].blank?
            claim_type = bgs_claim&.dig(:benefit_claim_details_dto, :bnft_claim_type_cd)
            detail = "SponsorICN is required for claim type #{claim_type}"
            raise ::Common::Exceptions::ResourceNotFound.new(detail:)
          end
          file_number_check(icn: params[:sponsorIcn])

          if @file_number.nil?
            claims_v2_logging('EWS_submit', level: :error,
                                            message: "EWS no file number error, claim_id: #{params[:id]}")

            raise ::Common::Exceptions::ResourceNotFound.new(detail:
              "Unable to locate Veteran's File Number. " \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
          end

          ews = create_ews(params[:id])
          ClaimsApi::EvidenceWaiverBuilderJob.perform_async(ews.id)

          render json: { success: true }
        end

        private

        def dependent_service(bgs_claim = nil)
          ClaimsApi::DependentService.new(bgs_claim:)
        end

        def create_ews(claim_id)
          attributes = {
            status: ClaimsApi::EvidenceWaiverSubmission::PENDING,
            auth_headers:,
            cid: source_cid,
            claim_id:
          }

          new_ews = ClaimsApi::EvidenceWaiverSubmission.create!(attributes)
          new_ews.auth_headers['va_eauth_birlsfilenumber'] = @file_number
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

          local_bgs_service.find_benefit_claim_details_by_benefit_claim_id(
            claim_id
          )
        end
      end
    end
  end
end
