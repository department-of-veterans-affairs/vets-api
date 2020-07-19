# frozen_string_literal: true

module BGS
  class VnpBenefitClaim < Service
    def initialize(proc_id:, veteran:, user:)
      @proc_id = proc_id
      @veteran = veteran

      super(user)
    end

    def create
      vnp_benefit_claim = create_benefit_claim

      {
        vnp_proc_id: vnp_benefit_claim[:vnp_proc_id],
        vnp_benefit_claim_id: vnp_benefit_claim[:vnp_bnft_claim_id],
        vnp_benefit_claim_type_code: vnp_benefit_claim[:bnft_claim_type_cd],
        claim_jrsdtn_lctn_id: vnp_benefit_claim[:claim_jrsdtn_lctn_id],
        intake_jrsdtn_lctn_id: vnp_benefit_claim[:intake_jrsdtn_lctn_id],
        participant_claimant_id: vnp_benefit_claim[:ptcpnt_clmant_id]
      }
    end

    def update(benefit_claim, vnp_benefit_claim)
      vnp_bnft_claim_update(benefit_claim, vnp_benefit_claim)
    end

    private

    def create_benefit_claim
      with_multiple_attempts_enabled do
        service.vnp_bnft_claim.vnp_bnft_claim_create(
          {
            vnp_proc_id: @proc_id,
            claim_rcvd_dt: Time.current.iso8601,
            status_type_cd: 'CURR',
            svc_type_cd: 'CP',
            pgm_type_cd: 'COMP',
            bnft_claim_type_cd: '130DPNEBNADJ',
            ptcpnt_clmant_id: @veteran[:vnp_participant_id],
            claim_jrsdtn_lctn_id: '335',
            intake_jrsdtn_lctn_id: '335',
            ptcpnt_mail_addrs_id: @veteran[:vnp_participant_address_id],
            vnp_ptcpnt_vet_id: @veteran[:vnp_participant_id],
            atchms_ind: 'N'
          }.merge(bgs_auth)
        )
      end
    end

    def vnp_bnft_claim_update(benefit_claim_record, vnp_benefit_claim_record)
      with_multiple_attempts_enabled do
        service.vnp_bnft_claim.vnp_bnft_claim_update(
          {
            vnp_proc_id: vnp_benefit_claim_record[:vnp_proc_id],
            vnp_bnft_claim_id: vnp_benefit_claim_record[:vnp_benefit_claim_id],
            bnft_claim_type_cd: benefit_claim_record[:claim_type_code],
            claim_rcvd_dt: Time.current.iso8601,
            bnft_claim_id: benefit_claim_record[:benefit_claim_id],
            intake_jrsdtn_lctn_id: vnp_benefit_claim_record[:intake_jrsdtn_lctn_id],
            claim_jrsdtn_lctn_id: vnp_benefit_claim_record[:claim_jrsdtn_lctn_id],
            pgm_type_cd: benefit_claim_record[:program_type_code],
            ptcpnt_clmant_id: vnp_benefit_claim_record[:participant_claimant_id],
            status_type_cd: benefit_claim_record[:status_type_code],
            svc_type_cd: 'CP'
          }.merge(bgs_auth)
        )
      end
    end
  end
end
