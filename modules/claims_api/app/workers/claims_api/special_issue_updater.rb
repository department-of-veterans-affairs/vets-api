# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module ClaimsApi
  class SpecialIssueUpdater
    include Sidekiq::Worker
    include SentryLogging

    # Update special issues for a single contention/disability
    def perform(user, contention_id, special_issues)
      service = bgs_service(user).contention

      claims = service.find_contentions_by_ptcpnt_id(user.participant_id)[:benefit_claims]
      claim = claim_from_contention_id(claims, contention_id)
      raise "Claim not found with contention: #{contention_id}" if claim.blank?

      options = required_claim_fields(claim)
      options = append_provided_special_issues(options, special_issues)

      service.manage_contentions(options)
    rescue BGS::ShareError, BGS::PublicError => e
      # TODO: https://vajira.max.gov/browse/API-3277
      log_exception_to_sentry(e)
    end

    def bgs_service(user)
      external_key = user.common_name || user.email

      BGS::Services.new(
        external_uid: user.icn || user.uuid,
        external_key: external_key
      )
    end

    def append_provided_special_issues(options, special_issues)
      options[:contentions].each do |contention|
        next unless contention[:cntntn_id] == contention_id

        special_issues.each do |special_issue|
          existing_special_issue = contention[:special_issues].find { |si| si[:spis_tc] == special_issue }
          contention[:special_issues].push({ spis_tc: special_issue }) if existing_special_issue.blank?
        end
      end

      options
    end

    def claim_from_contention_id(claims, contention_id)
      claims.each do |claim|
        next if claim[:contentions].blank?

        contention = claim[:contentions].find { |c| c[:cntntn_id] == contention_id }
        return claim if contention.present?
      end
    end

    def required_claim_fields(claim)
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
        contentions: existing_contentions(claim)
      }
    end

    def existing_contentions(claim)
      return [] if claims[:contentions].blank?

      claims[:contentions].map do |contention|
        {
          clm_id: claim[:clm_id],
          special_issues: existing_special_issues(contention)
        }
      end
    end

    def existing_special_issues(contention)
      return [] if contention[:special_issues].blank?

      contention[:special_issues].map do |special_issue|
        { spis_tc: special_issue }
      end
    end
  end
end
