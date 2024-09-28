# frozen_string_literal: true

require 'bgs_service/person_web_service'
require 'bgs_service/redis/find_poas_service'
require 'bgs_service/benefit_claim_web_service'
require 'bgs_service/benefit_claim_service'

module ClaimsApi
  class DependentClaimantPoaAssignmentService
    def initialize(**options)
      @poa_code = options[:poa_code]
      @veteran_participant_id = options[:veteran_participant_id]
      @dependent_participant_id = options[:dependent_participant_id]
      @veteran_file_number = options[:veteran_file_number]
    end

    def assign_poa_to_dependent! # rubocop:disable Metrics/MethodLength
      begin
        res = person_web_service.manage_ptcpnt_rlnshp_poa(ptcpnt_id_a: @dependent_participant_id,
                                                          ptcpnt_id_b: poa_participant_id)

        if manage_ptcpnt_rlnshp_poa_success?(res)
          ClaimsApi::Logger.log_info('POA assigned to dependent', dependent_participant_id: @dependent_participant_id,
                                                                  poa_code: @poa_code)
          return nil
        end
      rescue Common::Exceptions::ServiceError => e
        if e.errors.first.detail == 'PtcpntIdA has open claims.'
          ClaimsApi::Logger.log_info('Dependent has open claims, continuing.',
                                     dependent_participant_id: @dependent_participant_id)
        else
          raise
        end
      end

      # TODO: Verify whether we also need to filter by ptcpnt_clmant_id == @dependent_participant_id
      first_open_claim = dependent_claims.find { |claim| claim[:phase_type] != 'Complete' }
      first_open_claim_details = claim_details(first_open_claim[:claim_id])

      benefit_claim_update_input = {
        file_number: @veteran_file_number,
        payee_code: first_open_claim_details[:payee_type_cd],
        date_of_claim: first_open_claim_details[:claim_rcvd_dt] # TODO: Format
        # TODO: claimant_ssn, power_of_attorney, benefit_claim_type, old_end_product_code, new_end_product_label, etc.
      }

      benefit_claim_service.update_benefit_claim(benefit_claim_update_input)
    end

    private

    def person_web_service
      ClaimsApi::PersonWebService.new(external_uid: @dependent_participant_id,
                                      external_key: @dependent_participant_id)
    end

    def dependent_claims
      local_bgs = ClaimsApi::LocalBGS.new(external_uid: @dependent_participant_id,
                                          external_key: @dependent_participant_id)
      res = local_bgs.find_benefit_claims_status_by_ptcpnt_id(@dependent_participant_id)

      res&.fetch(:benefit_claims_dto, :benefit_claim)
    end

    def benefit_claim_web_service
      ClaimsApi::BenefitClaimWebService.new(external_uid: @dependent_participant_id,
                                            external_key: @dependent_participant_id)
    end

    def benefit_claim_service
      ClaimsApi::BenefitClaimService.new(external_uid: @dependent_participant_id,
                                         external_key: @dependent_participant_id)
    end

    def claim_details(claim_id)
      benefit_claim_web_service.find_bnft_claim(claim_id:)
    end

    def poa_participant_id
      poa_ptcpnt = FindPOAsService.new.response.find { |combo| combo[:legacy_poa_cd] == @poa_code }

      poa_ptcpnt&.dig(:ptcpnt_id)
    end

    def manage_ptcpnt_rlnshp_poa_success?(response)
      response.is_a?(Hash) && response.fetch(:comp_id, :ptcpnt_rlnshp_type_nm) == 'Power of Attorney For'
    end
  end
end
