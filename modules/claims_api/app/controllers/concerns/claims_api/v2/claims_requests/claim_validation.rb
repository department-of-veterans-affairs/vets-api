# frozen_string_literal: true

module ClaimsApi
  module V2
    module ClaimsRequests
      module ClaimValidation
        extend ActiveSupport::Concern

        def validate_id_with_icn(bgs_claim, lighthouse_claim, request_icn)
          if bgs_claim&.dig(:benefit_claim_details_dto).present?
            clm_prtcpnt_vet_id = bgs_claim&.dig(:benefit_claim_details_dto, :ptcpnt_vet_id)
            clm_prtcpnt_clmnt_id = bgs_claim&.dig(:benefit_claim_details_dto, :ptcpnt_clmant_id)
          end

          veteran_icn = if lighthouse_claim.present? && lighthouse_claim['veteran_icn'].present?
                          lighthouse_claim['veteran_icn']
                        end

          if clm_prtcpnt_cannot_access_claim?(clm_prtcpnt_vet_id, clm_prtcpnt_clmnt_id) && veteran_icn != request_icn
            raise ::Common::Exceptions::ResourceNotFound.new(
              detail: 'Invalid claim ID for the veteran identified.'
            )
          end
        end

        private

        def clm_prtcpnt_cannot_access_claim?(clm_prtcpnt_vet_id, clm_prtcpnt_clmnt_id)
          return true if clm_prtcpnt_vet_id.nil? || clm_prtcpnt_clmnt_id.nil?

          # if either of these is false then we have a match and can show the record
          clm_prtcpnt_vet_id != target_veteran.participant_id && clm_prtcpnt_clmnt_id != target_veteran.participant_id
        end
      end
    end
  end
end
