require_relative 'value_objects/vnp_benefit_claim'

module BGS
  class VnpBenefitClaim < Base
    def initialize(proc_id:, veteran:, user:)
      @proc_id = proc_id
      @veteran = veteran

      super(user) # is this cool? Might be smelly. Might indicate a new class/object 🤔
    end

    def create
      vnp_benefit_claim = create_benefit_claim(@proc_id, @veteran)

      {
        vnp_proc_id: vnp_benefit_claim[:vnp_proc_id],
        vnp_benefit_claim_id: vnp_benefit_claim[:vnp_bnft_claim_id],
        vnp_benefit_claim_type_code: vnp_benefit_claim[:bnft_claim_type_cd],
        claim_jrsdtn_lctn_id: vnp_benefit_claim[:claim_jrsdtn_lctn_id],
        intake_jrsdtn_lctn_id: vnp_benefit_claim[:intake_jrsdtn_lctn_id],
        participant_claimant_id: vnp_benefit_claim[:ptcpnt_clmant_id]
      }
    end


    # ::ValueObjects::VnpBenefitClaim.new(
    #   vnp_proc_id: benefit_claim[:vnp_proc_id],
    #   vnp_benefit_claim_id: benefit_claim[:vnp_bnft_claim_id],
    #   vnp_benefit_claim_type_code: benefit_claim[:bnft_claim_type_cd],
    #   claim_jrsdtn_lctn_id: benefit_claim[:claim_jrsdtn_lctn_id],
    #   intake_jrsdtn_lctn_id: benefit_claim[:intake_jrsdtn_lctn_id],
    #   claim_received_date: benefit_claim[:claim_rcvd_dt],
    #   program_type_code: benefit_claim[:pgm_type_cd],
    #   participant_claimant_id: benefit_claim[:ptcpnt_clmant_id],
    #   status_type_code: benefit_claim[:status_type_cd],
    #   service_type_code: benefit_claim[:svc_type_cd],
    #   participant_mail_address_id: benefit_claim[:ptcpnt_mail_addrs_id],
    #   vnp_participant_vet_id: benefit_claim[:vnp_ptcpnt_vet_id]
    # )

    def update(benefit_claim, vnp_benefit_claim_record)
      vnp_bnft_claim_update(benefit_claim, vnp_benefit_claim_record)
    end
  end
end