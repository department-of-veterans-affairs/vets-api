# frozen_string_literal: true

require 'bgs'
require 'token_validation/v2/client'
require 'claims_api/claim_logger'
require 'claims_api/dependent_service'
require 'claims_api/v2/error/lighthouse_error_handler'
require 'claims_api/v2/evidence_waiver_submission_validation'

module ClaimsApi
  module V2
    module Veterans
      class EvidenceWaiverController < ClaimsApi::V2::Veterans::Base
        include ClaimsApi::V2::EvidenceWaiverSubmissionValidation
        include ClaimsApi::V2::Error::LighthouseErrorHandler
        skip_before_action :validate_json_format
        before_action :set_lighthouse_claim, :set_bgs_claim!, :verify_if_dependent_claim!
        FORM_NUMBER = '5103'

        def submit
          if params&.dig('data', 'attributes', 'trackedItemIds').present?
            tracked_item_ids = params['data']['attributes']['trackedItemIds']
            @claims_api_forms_validation_errors = validate_form_5103_submission_values(params)
            if @claims_api_forms_validation_errors
              raise ::ClaimsApi::Common::Exceptions::Lighthouse::UnprocessableEntity,
                    @claims_api_forms_validation_errors
            end
          end

          validate_veteran_name(false)
          ews = create_ews(params[:id])
          tracked_item_ids&.each { |id| ews.tracked_items << id }
          ews.save
          ClaimsApi::EvidenceWaiverBuilderJob.perform_async(ews.id)

          render json: { success: true }, status: :accepted
        end

        private

        def set_lighthouse_claim
          @lighthouse_claim = find_lighthouse_claim!(claim_id: params[:id])
        end

        def set_bgs_claim!
          benefit_claim_id = @lighthouse_claim.present? ? @lighthouse_claim.evss_id : params[:id]
          @bgs_claim = find_bgs_claim!(claim_id: benefit_claim_id)

          raise ::Common::Exceptions::ResourceNotFound.new(detail: 'Claim not found') if @bgs_claim.blank?
        end

        def verify_if_dependent_claim!
          @pctpnt_vet_id = @bgs_claim&.dig(:benefit_claim_details_dto, :ptcpnt_vet_id)
          if @pctpnt_vet_id.blank?
            raise ::Common::Exceptions::ResourceNotFound.new(detail:
              'Veteran participant id is required for uploading to Benefits Documents')
          end

          pctpnt_clmant_id = @bgs_claim&.dig(:benefit_claim_details_dto, :ptcpnt_clmant_id)
          if target_veteran.participant_id != @pctpnt_vet_id && target_veteran.participant_id != pctpnt_clmant_id
            raise ::Common::Exceptions::Unauthorized.new(detail:
              'Claim does not belong to this veteran')
          end

          @dependent_filing = @pctpnt_vet_id != pctpnt_clmant_id && target_veteran.participant_id == pctpnt_clmant_id

          if @dependent_filing
            claims_v2_logging('EWS_submit', level: :info,
                                            message: '5103 filed by dependent claimant')
          end
        end

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
          # ensure that in the case of a dependent claimant this gets into the correct folder
          new_ews.auth_headers['target_veteran_folder_id'] = @pctpnt_vet_id
          new_ews.auth_headers['dependent'] = @dependent_filing
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

          bgs_claim_status_service.find_benefit_claim_details_by_benefit_claim_id(
            claim_id
          )
        end
      end
    end
  end
end
