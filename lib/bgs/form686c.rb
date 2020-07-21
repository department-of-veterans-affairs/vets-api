# frozen_string_literal: true

module BGS
  class Form686c < Service
    def initialize(user)
      @user = user.with_indifferent_access
    end

    def submit(payload)
      proc_id = create_proc_id_and_form
      veteran = VnpVeteran.new(proc_id: proc_id, payload: payload, user: @user).create

      process_relationships(proc_id, veteran, payload)

      vnp_benefit_claim = VnpBenefitClaim.new(proc_id: proc_id, veteran: veteran, user: @user)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      benefit_claim_record = BenefitClaim.new(
        vnp_benefit_claim: vnp_benefit_claim_record,
        veteran: veteran,
        user: @user
      ).create

      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
      update_proc(proc_id)
    end

    private

    def create_proc
      with_multiple_attempts_enabled do
        service.vnp_proc_v2.vnp_proc_create(
          {
            vnp_proc_type_cd: 'DEPCHG',
            vnp_proc_state_type_cd: 'Started'
          }.merge(bgs_auth)
        )
      end
    end

    def create_proc_form(vnp_proc_id)
      with_multiple_attempts_enabled do
        service.vnp_proc_form.vnp_proc_form_create(
          {
            vnp_proc_id: vnp_proc_id,
            form_type_cd: '21-686c'
          }.merge(bgs_auth)
        )
      end
    end

    def update_proc(proc_id)
      with_multiple_attempts_enabled do
        service.vnp_proc_v2.vnp_proc_update(
          {
            vnp_proc_id: proc_id,
            vnp_proc_state_type_cd: 'Ready'
          }.merge(bgs_auth)
        )
      end
    end

    def process_relationships(proc_id, veteran, payload)
      dependents = Dependents.new(proc_id: proc_id, payload: payload, user: @user).create
      marriages = Marriages.new(proc_id: proc_id, payload: payload, user: @user).create

      all_dependents = dependents + marriages

      VnpRelationships.new(proc_id: proc_id, veteran: veteran, dependents: all_dependents, user: @user).create
      process_674(proc_id, dependents, payload)
    end

    def process_674(proc_id, dependents, payload)
      dependents.each do |dependent|
        if dependent[:type] == '674'
          StudentSchool.new(
            proc_id: proc_id,
            vnp_participant_id: dependent[:vnp_participant_id],
            payload: payload,
            user: @user
          ).create
        end
      end
    end

    def create_proc_id_and_form
      vnp_response = create_proc
      create_proc_form(vnp_response[:vnp_proc_id])

      vnp_response[:vnp_proc_id]
    end
  end
end
