module BGS
  class SubmitForm686cJob
  #  should we do retries? If so, how many?
  #   ex.
  #   sidekiq_options(retry: 10)

    class SubmitForm86cError < Common::Exceptions::BackendServiceException; end

    # Performs async submission to BGS for 686c form

    # perform method from example: app/workers/central_mail/submit_form4142_job.rb
    # has a 'submission id' and 'tracking'. What's that?
    def perform(user, payload)
      proc_id = create_proc_id_and_form(user)
      veteran = BGS::VnpVeteran.new(proc_id: proc_id, payload: payload, user: user).create
      dependents = BGS::Dependents.new(proc_id: proc_id, veteran: veteran, payload: payload, user: user).create
      VnpRelationships.new(proc_id: proc_id, veteran: veteran, dependents: dependents, user: user).create

      vnp_benefit_claim = BGS::VnpBenefitClaim.new(proc_id: proc_id, veteran: veteran, user: user)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      benefit_claim_record = BGS::BenefitClaim.new(vnp_benefit_claim: vnp_benefit_claim_record, veteran: veteran, user: user).create
      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
      update_proc(proc_id)
    end

    private

    def create_proc_id_and_form(user)
      bgs_base = BGS::Base.new(user)
      vnp_response = bgs_base.create_proc
      bgs_base.create_proc_form(vnp_response[:vnp_proc_id])

      vnp_response[:vnp_proc_id]
    end
  end
end