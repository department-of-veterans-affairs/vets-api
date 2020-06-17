# frozen_string_literal: true

module BGS
  class DependentService < Base
    def initialize(user)
      @user = user
    end

    # class BGSError < Common::Exceptions::BackendServiceException; end

    def get_dependents
      service
        .claimants
        .find_dependents_by_participant_id(
          @user.participant_id, @user.ssn
        )
    end

    def modify_dependents(payload = nil)
      # BGS::SubmitForm686cJob.perform_async(@user, payload) this is for the job
      # delete_me_root = Rails.root.to_s
      # delete_me_payload_file = File.read("#{delete_me_root}/spec/services/bgs/support/final_payload.json")
      # payload = JSON.parse(delete_me_payload_file)
      hash_payload = payload.to_h


      proc_id = create_proc_id_and_form
      veteran = VnpVeteran.new(proc_id: proc_id, payload: hash_payload, user: @user).create
      dependents = Dependents.new(proc_id: proc_id, payload: hash_payload, user: @user).create

      VnpRelationships.new(proc_id: proc_id, veteran: veteran, dependents: dependents, user: @user).create

      # if payload['report674']
      #   StudentSchool.new(proc_id: proc_id, vnp_participant_id: dependent.vnp_participant_id, payload: payload, user: @user).create
      # end
      vnp_benefit_claim = VnpBenefitClaim.new(proc_id: proc_id, veteran: veteran, user: @user)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      benefit_claim_record = BenefitClaim.new(vnp_benefit_claim: vnp_benefit_claim_record, veteran: veteran, user: @user).create
      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
      update_proc(proc_id)
      # payload
      # {response: 'ok'} this is for the job
    end

    private

    def create_proc_id_and_form
      # bgs_base = BGS::Base.new(user)
      # vnp_response = bgs_base.create_proc
      vnp_response = create_proc
      create_proc_form(vnp_response[:vnp_proc_id])

      vnp_response[:vnp_proc_id]
    end
  end
end

