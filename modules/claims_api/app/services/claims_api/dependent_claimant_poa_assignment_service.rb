# frozen_string_literal: true

require 'date'
require 'bgs_service/person_web_service'
require 'bgs_service/redis/find_poas_service'
require 'bgs_service/benefit_claim_web_service'
require 'bgs_service/benefit_claim_service'
require 'bgs_service/e_benefits_bnft_claim_status_web_service'

module ClaimsApi
  class DependentClaimantPoaAssignmentService
    def initialize(**options)
      @poa_id = options[:poa_id]
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

      log(level: :error, detail: 'Failed to assign POA to dependent')

      raise ::Common::Exceptions::ServiceError
    end

    private

    def person_web_service
      ClaimsApi::PersonWebService.new(external_uid: @dependent_participant_id,
                                      external_key: @dependent_participant_id)
    end

    def log(level: :info, **rest)
      ClaimsApi::Logger.log('dependent_claimant_poa_assignment_service', level:, poa_id: @poa_id, poa_code: @poa_code,
                                                                         **rest)
    end

    def assign_poa_to_dependent_via_manage_ptcpnt_rlnshp?
      res = person_web_service.manage_ptcpnt_rlnshp_poa(ptcpnt_id_a: @dependent_participant_id,
                                                        ptcpnt_id_b: poa_participant_id,
                                                        authzn_poa_access_ind: @allow_poa_access,
                                                        authzn_change_clmant_addrs_ind: @allow_poa_cadd)

      if manage_ptcpnt_rlnshp_poa_success?(res)
        log(detail: 'POA assigned to dependent.')

        return true
      end

      raise ::Common::Exceptions::ServiceError
    rescue ::Common::Exceptions::ServiceError => e
      if e.errors.first.detail == 'PtcpntIdA has open claims.'
        log(detail: 'Dependent has open claims, continuing.')

        return false
      end

      raise e
    rescue => e
      log(level: :error, detail: 'Something else went wrong with manage_ptcpnt_rlnshp.', error: error_details(e))

      raise e
    end

    def error_details(e)
      {
        message: e.message,
        detail: e.try(:detail),
        details: e.try(:details),
        errors: e.try(:errors)&.map(&:to_h)
      }.compact
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
      first_open_claim_details

      if first_open_claim_details.nil? || first_open_claim_details.blank?
        log(detail: 'Dependent has no open claims.', statuses: dependent_claims.pluck(:phase_type).uniq)

        raise ::Common::Exceptions::ServiceError
      end

      benefit_claim_update_input = build_benefit_claim_update_input(claim_details: first_open_claim_details)

      result = benefit_claim_service.update_benefit_claim(benefit_claim_update_input)

      if result[:return][:return_message] == 'Update to Corporate was successful'
        log(detail: 'POA assigned to dependent.')

        return true
      end

      false
    end

    def dependent_claims
      res = e_benefits_bnft_claim_status_web_service.find_benefit_claims_status_by_ptcpnt_id(@dependent_participant_id)

      benefit_claims = Array.wrap(res&.dig(:benefit_claims_dto, :benefit_claim))

      return benefit_claims if benefit_claims.present? && benefit_claims.is_a?(Array) && benefit_claims.first.present?

      log(level: :error, detail: 'Dependent claims not found in BGS')

      raise ::Common::Exceptions::ResourceNotFound
    end

    def e_benefits_bnft_claim_status_web_service
      @e_benefits_bnft_claim_status_web_service ||= ClaimsApi::EbenefitsBnftClaimStatusWebService.new(
        external_uid: @dependent_participant_id,
        external_key: @dependent_participant_id
      )
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

      return res&.dig(:bnft_claim_dto) if res&.dig(:bnft_claim_dto).present?

      log(level: :error, detail: 'Claim details not found in BGS', claim_id:)

      raise ::Common::Exceptions::ResourceNotFound
    end

    def poa_participant_id
      poa_ptcpnt = FindPOAsService.new.response.find { |combo| combo[:legacy_poa_cd] == @poa_code }

      return poa_ptcpnt&.dig(:ptcpnt_id) if poa_ptcpnt&.dig(:ptcpnt_id).present?

      log(level: :error, detail: 'POA code/participant ID combo not found in BGS')

      raise ::Common::Exceptions::ResourceNotFound
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
        log(level: :error, detail: 'Program type code not recognized', pgm_type_cd:)

        raise ::Common::Exceptions::BadRequest
      end
    end

    def first_open_claim_details
      first_open_claim = dependent_claims.find do |claim|
        claim[:phase_type] != 'Complete' && claim[:ptcpnt_vet_id] == @veteran_participant_id
      end

      if first_open_claim.present?
        claim_details(first_open_claim[:benefit_claim_id])
      elsif first_open_claim.nil?
        open_claims = benefit_claim_web_service.find_bnft_claim_by_clmant_id(
          dependent_participant_id: @dependent_participant_id
        )
        first_claim_id = open_claims.present? ? open_claims[:bnft_claim_dto].first[:bnft_claim_id] : nil
        claim_details(first_claim_id)
      end
    end
  end
end
