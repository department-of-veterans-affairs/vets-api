# frozen_string_literal: true

module ClaimsApi
  module V2
    class ClaimValidator
      def initialize(bgs_claim, lighthouse_claim, request_icn, target_veteran)
        @bgs_claim = bgs_claim
        @lighthouse_claim = lighthouse_claim
        @request_icn = request_icn
        @target_veteran = target_veteran
      end

      def validate!
        byebug
        unless valid_claim_with_id_with_icn?
          raise ::Common::Exceptions::ResourceNotFound.new(
            detail: 'Invalid claim ID for the veteran identified.'
          )
        end
      end

      private

      def valid_claim_with_id_with_icn?
        byebug
        if @bgs_claim&.dig(:benefit_claim_details_dto).present?
          clm_prtcpnt_vet_id = @bgs_claim&.dig(:benefit_claim_details_dto, :ptcpnt_vet_id)
          clm_prtcpnt_clmnt_id = @bgs_claim&.dig(:benefit_claim_details_dto, :ptcpnt_clmant_id)
        end

        veteran_icn = if @lighthouse_claim.present? && @lighthouse_claim['veteran_icn'].present?
                        @lighthouse_claim['veteran_icn']
                      end
byebug
        if clm_prtcpnt_cannot_access_claim?(clm_prtcpnt_vet_id, clm_prtcpnt_clmnt_id) && veteran_icn != @request_icn
          raise ::Common::Exceptions::ResourceNotFound.new(
            detail: 'Invalid claim ID for the veteran identified.'
          )
        end

        true
      end

      def clm_prtcpnt_cannot_access_claim?(clm_prtcpnt_vet_id, clm_prtcpnt_clmnt_id)
        byebug
        return true if clm_prtcpnt_vet_id.nil? || clm_prtcpnt_clmnt_id.nil?

        return false if validated_clm_prtcpnt_vet_id(clm_prtcpnt_vet_id)

        false if validated_clm_prtcpnt_clmnt_id(clm_prtcpnt_clmnt_id)
      end

      def validated_clm_prtcpnt_vet_id(clm_prtcpnt_vet_id)
        clm_prtcpnt_vet_id != @target_veteran.participant_id
      end

      def validated_clm_prtcpnt_clmnt_id(clm_prtcpnt_clmnt_id)
        clm_prtcpnt_clmnt_id != @target_veteran.participant_id
      end
    end
  end
end
