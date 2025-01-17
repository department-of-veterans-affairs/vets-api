# frozen_string_literal: true

require 'bgs_service/contention_service'

module ClaimsApi
  class SpecialIssueUpdater < UpdaterService
    # Update special issues for a single contention/disability
    #
    # @param user [OpenStruct] Veteran to attach special issues to
    # @param contention_id [Hash(claim_id:, code:, name:)] Identifier to match existing contention
    # @param special_issues [Array(String)] List of special issues to append
    # @param auto_claim_id [Integer] default: nil
    def perform(contention_id, special_issues, auto_claim_id)
      user = bgs_headers(auto_claim_id)

      contention_id.symbolize_keys!
      validate_contention_id_structure(contention_id)
      service = if Flipper.enabled?(:claims_api_special_issues_updater_uses_local_bgs)
                  contention_service(user)
                else
                  bgs_ext_service(user).contention
                end

      claims = service.find_contentions_by_ptcpnt_id(user['participant_id'])[:benefit_claims] || []
      claim = claim_from_contention_id(claims, contention_id)
      raise "Claim not found with contention: #{contention_id}" if claim.blank?

      options = required_claim_fields(claim, contention_id, special_issues)
      service.manage_contentions(options)
    rescue BGS::ShareError, BGS::PublicError => e
      log_exception_to_claim_record(auto_claim_id, { key: e.code, text: e.message })
      log_exception_to_sentry(e)
    end

    # Store off exception information on the claim record within the database
    #
    # @param auto_claim_id [Integer] Applied to that particular claim id if provided
    # @param message [any] Anything in any format that explains the error
    def log_exception_to_claim_record(auto_claim_id, message)
      return if auto_claim_id.blank?

      auto_claim = ClaimsApi::AutoEstablishedClaim.find(auto_claim_id)
      auto_claim.bgs_special_issue_responses = [] if auto_claim.bgs_special_issue_responses.blank?
      auto_claim.bgs_special_issue_responses = auto_claim.bgs_special_issue_responses + [message]
      auto_claim.save
    end

    # Passthru to allow calling from sidekiq_retries_exhausted section above
    #
    # @param auto_claim_id [Integer] Applied to that particular claim id if provided
    # @param message [any] Anything in any format that explains the error
    def self.log_exception_to_claim_record(auto_claim_id, message)
      ClaimsApi::SpecialIssueUpdater.new.log_exception_to_claim_record(auto_claim_id, message)
    end

    # Passthru to allow calling from sidekiq_retries_exhausted section above
    #
    # @param e [StandardError] Error to be logged
    def self.log_exception_to_sentry(e)
      ClaimsApi::SpecialIssueUpdater.new.log_exception_to_sentry(e)
    end

    # Service object to interface with BGS
    #
    # @param user [OpenStruct] Veteran to attach special issues to
    # @return [BGS::Services] Service object
    def bgs_ext_service(user)
      BGS::Services.new(
        external_uid: user['ssn'],
        external_key: user['ssn']
      )
    end

    def contention_service(user)
      ClaimsApi::ContentionService.new(
        external_uid: user['ssn'],
        external_key: user['ssn']
      )
    end

    # Find matching claim within all claims for the particular participant
    #
    # @param claims [Array(Hash)] List of BGS claim objects
    # @param contention_id [Hash(claim_id:, code:, name:)] Identifier to match existing contention
    # @return [Hash] Particular BGS claim object if found, nil if not found
    def claim_from_contention_id(claims, contention_id)
      claims.each do |claim|
        next if claim[:contentions].blank?

        contentions = claim[:contentions].is_a?(Hash) ? [claim[:contentions]] : claim[:contentions]
        contention = contentions.find { |c| matches_contention?(contention_id, c) }
        return claim if contention.present?
      end

      nil
    end

    # Generate expected payload for updating special issues through BGS
    #
    # @param claim [Hash] BGS claim object
    # @param contention_id [Hash(claim_id:, code:, name:)] Identifier to match existing contention
    # @param special_issues [Array(String)] List of special issues to append
    # @return [Hash] Expected payload to send to BGS
    def required_claim_fields(claim, contention_id, special_issues)
      {
        jrn_dt: claim[:jrn_dt],
        bnft_clm_tc: claim[:bnft_clm_tc],
        bnft_clm_tn: claim[:bnft_clm_tn],
        claim_rcvd_dt: claim[:claim_rcvd_dt],
        clm_id: claim[:clm_id],
        lc_stt_rsn_tc: claim[:lc_stt_rsn_tc],
        lc_stt_rsn_tn: claim[:lc_stt_rsn_tn],
        lctn_id: claim[:lctn_id],
        non_med_clm_desc: claim[:non_med_clm_desc],
        prirty: claim[:prirty],
        ptcpnt_id_clmnt: claim[:ptcpnt_id_clmnt],
        ptcpnt_id_vet: claim[:ptcpnt_id_vet],
        ptcpnt_suspns_id: claim[:ptcpnt_suspns_id],
        soj_lctn_id: claim[:soj_lctn_id],
        contentions: existing_contentions(claim, contention_id, special_issues)
      }
    end

    # Generate expected contentions payload.
    #
    # @param claim [Hash] BGS claim object
    # @param contention_id [Hash(claim_id:, code:, name:)] Identifier to match existing contention
    # @param special_issues [Array(String)] List of special issues to append
    # @return [Hash] Expected payload to send to BGS
    def existing_contentions(claim, contention_id, special_issues)
      return [] if claim[:contentions].blank?

      contentions = claim[:contentions].is_a?(Hash) ? [claim[:contentions]] : claim[:contentions]
      contentions.map do |contention|
        si = matches_contention?(contention_id, contention) ? special_issues : []
        {
          clm_id: claim[:clm_id],
          cntntn_id: contention[:cntntn_id],
          special_issues: existing_special_issues(contention, si)
        }
      end
    end

    # Generate expected special issues payload.
    # Append any new special issues as well.
    #
    # @param contention [Hash] BGS claim object
    # @param special_issues [Array(String)] List of special issues to append
    # @return [Hash] Expected payload to send to BGS
    def existing_special_issues(contention, special_issues = [])
      contention[:special_issues] = [] if contention[:special_issues].blank?

      contentions = Array.wrap(contention[:special_issues])

      unique_special_issues = (special_issues + contentions.pluck(:spis_tc)).uniq
      unique_special_issues.map do |special_issue|
        { spis_tc: special_issue }
      end
    end

    # Returns true if provided contention matches up with provided contention identifier
    #
    # @return [Boolean] true if matches, false if not
    def matches_contention?(contention_id, contention)
      return false if contention[:clm_id] != contention_id[:claim_id].to_s
      return true if contention_id[:code].present? && contention[:clsfcn_id] == contention_id[:code].to_s

      contention_id[:code].blank? && contention_id[:name].to_s == contention[:clmnt_txt]
    end

    # Ensure contention_id provided is a valid starting structure
    #
    # @param contention_id [Hash(claim_id:, code:, name:)] Identifier to match existing contention
    def validate_contention_id_structure(contention_id)
      if contention_id.is_a?(Hash) &&
         contention_id[:claim_id].present? &&
         (contention_id[:name].present? || contention_id[:code].present?)
        return
      end

      raise "Invalid contention_id: #{contention_id}"
    end
  end
end
