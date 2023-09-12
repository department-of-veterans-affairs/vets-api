# frozen_string_literal: true

require 'bgs'
require 'token_validation/v2/client'
require 'claims_api/claim_logger'

module ClaimsApi
  module V2
    module Veterans
      class EvidenceWaiverController < ClaimsApi::V2::ApplicationController
        before_action :file_number_check

        def submit
          lighthouse_claim = find_lighthouse_claim!(claim_id: params[:id])
          benefit_claim_id = lighthouse_claim.present? ? lighthouse_claim.evss_id : params[:id]
          bgs_claim = find_bgs_claim!(claim_id: benefit_claim_id)

          if @file_number.nil?
            ClaimsApi::Logger.log('EWS',
                                  detail: 'EWS no file number error', claim_id: params[:id])

            raise ::Common::Exceptions::ResourceNotFound.new(detail:
              "Unable to locate Veteran's File Number. " \
              'Please submit an issue at ask.va.gov or call 1-800-MyVA411 (800-698-2411) for assistance.')
          end

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

        def file_number_check
          @file_number = local_bgs_service.find_by_ssn(target_veteran.ssn)&.dig(:file_nbr) # rubocop:disable Rails/DynamicFindBy

        # catch any other errors related to this call failing
        rescue => e
          log_exception_to_sentry(e, nil, { message: e.errors[0].detail }, 'warn')
          raise ::Common::Exceptions::FailedDependency.new(
            detail: "An external system failure occurred while trying to retrieve Veteran 'FileNumber'"
          )
        end
      end
    end
  end
end
