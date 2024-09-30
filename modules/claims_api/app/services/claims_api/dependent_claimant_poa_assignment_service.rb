# frozen_string_literal: true

require 'date'
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
      @allow_poa_access = options[:allow_poa_access]
      @allow_poa_cadd = options[:allow_poa_cadd]
      @claimant_ssn = options[:claimant_ssn]
    end

    def assign_poa_to_dependent!
      return nil if assign_poa_to_dependent_via_manage_ptcpnt_rlnshp?

      return nil if assign_poa_to_dependent_via_update_benefit_claim?

      raise 'Failed to assign POA to dependent'
    end

    private

    def person_web_service
      ClaimsApi::PersonWebService.new(external_uid: @dependent_participant_id,
                                      external_key: @dependent_participant_id)
    end

    def assign_poa_to_dependent_via_manage_ptcpnt_rlnshp?
      res = person_web_service.manage_ptcpnt_rlnshp_poa(ptcpnt_id_a: @dependent_participant_id,
                                                        ptcpnt_id_b: poa_participant_id)

      if manage_ptcpnt_rlnshp_poa_success?(res)
        ClaimsApi::Logger.log('dependent_claimant_poa_assignment_service',
                              dependent_participant_id: @dependent_participant_id,
                              poa_code: @poa_code, detail: 'POA assigned to dependent.')

        true
      end
    rescue ::Common::Exceptions::ServiceError => e
      if e.errors.first.detail == 'PtcpntIdA has open claims.'
        ClaimsApi::Logger.log('dependent_claimant_poa_assignment_service',
                              dependent_participant_id: @dependent_participant_id,
                              detail: 'Dependent has open claims, continuing.')

        false
      else
        raise 'Failed to assign POA to dependent'
      end
    end

    def iso_to_date(iso_date)
      DateTime.parse(iso_date).strftime('%m/%d/%Y')
    end

    def build_benefit_claim_update_input(claim_details:)
      claim_rcvd_dt = iso_to_date(claim_details[:claim_rcvd_dt])

      {
        file_number: @veteran_file_number,
        payee_code: claim_details[:payee_type_cd],
        date_of_claim: claim_rcvd_dt,
        claimant_ssn: @claimant_ssn,
        power_of_attorney: @poa_code,
        benefit_claim_type: benefit_claim_type(claim_details[:pgm_type_cd]),
        old_end_product_code: claim_details[:cp_claim_end_prdct_type_cd],
        new_end_product_label: claim_details[:bnft_claim_type_cd],
        old_date_of_claim: claim_rcvd_dt,
        allow_poa_access: @allow_poa_access,
        allow_poa_cadd: @allow_poa_cadd
      }
    end

    def assign_poa_to_dependent_via_update_benefit_claim?
      first_open_claim = dependent_claims.find do |claim|
        claim[:phase_type] != 'Complete' && claim[:ptcpnt_vet_id] == @veteran_participant_id
      end
      first_open_claim_details = claim_details(first_open_claim[:benefit_claim_id])

      benefit_claim_update_input = build_benefit_claim_update_input(claim_details: first_open_claim_details)

      result = benefit_claim_service.update_benefit_claim(benefit_claim_update_input)

      if result[:return][:return_message] == 'Update to Corporate was successful'
        ClaimsApi::Logger.log('dependent_claimant_poa_assignment_service',
                              dependent_participant_id: @dependent_participant_id,
                              poa_code: @poa_code, detail: 'POA assigned to dependent.')

        return true
      end

      false
    end

    def dependent_claims
      local_bgs = ClaimsApi::LocalBGS.new(external_uid: @dependent_participant_id,
                                          external_key: @dependent_participant_id)
      res = local_bgs.find_benefit_claims_status_by_ptcpnt_id(@dependent_participant_id)

      res&.dig(:benefit_claims_dto, :benefit_claim)
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
      res = benefit_claim_web_service.find_bnft_claim(claim_id:)

      res&.dig(:bnft_claim_dto)
    end

    def poa_participant_id
      poa_ptcpnt = FindPOAsService.new.response.find { |combo| combo[:legacy_poa_cd] == @poa_code }

      poa_ptcpnt&.dig(:ptcpnt_id).presence || raise('POA code not found')
    end

    def manage_ptcpnt_rlnshp_poa_success?(response)
      response.is_a?(Hash) && response.dig(:comp_id, :ptcpnt_rlnshp_type_nm) == 'Power of Attorney For'
    end

    def benefit_claim_type(pgm_type_cd)
      case pgm_type_cd
      when 'CPL'
        '1'
      when 'CPD'
        '2'
      else
        raise 'Program type code not recognized'
      end
    end
  end
end
