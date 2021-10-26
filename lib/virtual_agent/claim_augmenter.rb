# frozen_string_literal: true

module V0
  module VirtualAgent
    class ClaimAugmenter
      def get_supplemental_claim_data(claims, current_user, service)
        claims.map do |claim|
          claim_db_record = EVSSClaim.for_user(current_user).find_by(evss_id: claim[:evss_id])
          single_claim_response = {}
          synchronized = 'REQUESTED'
          attempts = 0
          until (synchronized == 'SUCCESS') || (attempts == 20)
            single_claim_response, synchronized = service.update_from_remote(claim_db_record)
            sleep(1) if synchronized == 'REQUESTED'
            attempts += 1
          end

          if synchronized == 'SUCCESS'
            va_representative = get_va_representative(single_claim_response)
            transform_single_claim_to_augmented_response(claim, va_representative)
          else
            transform_single_claim_to_augmented_response(claim, '')
          end
        end
      end

      def transform_single_claim_to_augmented_response(claim, va_representative)
        { claim_status: claim[:claim_status],
          claim_type: claim[:claim_type],
          filing_date: claim[:filing_date],
          evss_id: claim[:evss_id],
          updated_date: claim[:updated_date],
          va_representative: va_representative }
      end

      def get_va_representative(claim)
        va_rep = claim.data['poa']
        va_rep.gsub(/&[^ ;]+;/, '')
      end
    end
  end
end
