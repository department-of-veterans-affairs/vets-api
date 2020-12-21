# frozen_string_literal: true

require 'sidekiq'
require 'sentry_logging'

module ClaimsApi
  class SpecialIssueUpdater
    include Sidekiq::Worker
    include SentryLogging

    def perform(user, special_issues, auto_established_claim)
      service = bgs_service(user).contention

      contentions = service.find_contentions_by_ptcpnt_id(user.participant_id)

      matching_contentions =
        contentions[:benefit_claims].select { |claim| claim[:clm_id] == auto_established_claim&.evss_id.to_s }

      matching_contentions.each do |contention|
        options = contention_options(contention)

        options[:contentions] =
          [{
            clm_id: contention[:clm_id],
            special_issues: special_issues.map { |special_issue| { spis_tc: special_issue } }
          }]

        service.manage_contentions(options)
      end
    rescue => e
      log_exception_to_sentry(e)
    end

    def bgs_service(user)
      external_key = user.common_name || user.email

      BGS::Services.new(
        external_uid: user.icn || user.uuid,
        external_key: external_key
      )
    end

    def contention_options(contention)
      {
        jrn_dt: contention[:jrn_dt],
        bnft_clm_tc: contention[:bnft_clm_tc],
        bnft_clm_tn: contention[:bnft_clm_tn],
        claim_rcvd_dt: contention[:claim_rcvd_dt],
        clm_id: contention[:clm_id],
        lc_stt_rsn_tc: contention[:lc_stt_rsn_tc],
        lc_stt_rsn_tn: contention[:lc_stt_rsn_tn],
        lctn_id: contention[:lctn_id],
        non_med_clm_desc: contention[:non_med_clm_desc],
        prirty: contention[:prirty],
        ptcpnt_id_clmnt: contention[:ptcpnt_id_clmnt],
        ptcpnt_id_vet: contention[:ptcpnt_id_vet],
        ptcpnt_suspns_id: contention[:ptcpnt_suspns_id],
        soj_lctn_id: contention[:soj_lctn_id]
      }
    end
  end
end
