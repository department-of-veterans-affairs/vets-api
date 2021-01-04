# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module ClaimsApi
  class SpecialIssueUpdater
    include Sidekiq::Worker
    include SentryLogging

    sidekiq_retries_exhausted do |message|
      # TODO: https://vajira.max.gov/browse/API-3277
      log_exception_to_sentry(StandardError.new("Failed to apply special issues to contention: #{message}"))
    end

    # Update special issues for a single contention/disability
    #
    # @param user [OpenStruct] Veteran to attach special issues to
    # @param contention_id [Hash(claim_id:, code:, name:)] Identifier to match existing contention
    # @param special_issues [Array(String)] List of special issues to append
    def perform(user, contention_id, special_issues)
      validate_contention_id_structure(contention_id)
      service = bgs_service(user).contention

      claims = service.find_contentions_by_ptcpnt_id(user.participant_id)[:benefit_claims]
      claim = claim_from_contention_id(claims, contention_id)
      raise "Claim not found with contention: #{contention_id}" if claim.blank?

      options = required_claim_fields(claim, contention_id, special_issues)
      service.manage_contentions(options)
    rescue BGS::ShareError, BGS::PublicError => e
      # TODO: https://vajira.max.gov/browse/API-3277
      log_exception_to_sentry(e)
    end

    # Service object to interface with BGS
    #
    # @param user [OpenStruct] Veteran to attach special issues to
    # @return [BGS::Services] Service object
    def bgs_service(user)
      external_key = user.common_name || user.email

      BGS::Services.new(
        external_uid: user.icn || user.uuid,
        external_key: external_key
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

        contention = claim[:contentions].find { |c| matches_contention?(contention_id, c) }
        return claim if contention.present?
      end
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

      claim[:contentions].map do |contention|
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

      unique_special_issues = (special_issues + (contention[:special_issues].map { |si| si[:spis_tc] })).uniq
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
