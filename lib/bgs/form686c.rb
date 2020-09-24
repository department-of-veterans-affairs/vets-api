# frozen_string_literal: true

require_relative 'benefit_claim'
require_relative 'dependents'
require_relative 'marriages'
require_relative 'service'
require_relative 'student_school'
require_relative 'vnp_benefit_claim'
require_relative 'vnp_relationships'
require_relative 'vnp_veteran'

module BGS
  class Form686c
    def initialize(user)
      @user = user
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
        user: @user,
        proc_id: proc_id
      ).create

      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
      bgs_service.update_proc(proc_id)
    end

    private

    def process_relationships(proc_id, veteran, payload)
      dependents = Dependents.new(proc_id: proc_id, payload: payload, user: @user).create_all
      marriages = Marriages.new(proc_id: proc_id, payload: payload, user: @user).create_all
      children = Children.new(proc_id: proc_id, payload: payload, user: @user).create_all

      veteran_dependents = dependents + marriages + children[:dependents]

      VnpRelationships.new(
        proc_id: proc_id,
        veteran: veteran,
        dependents: veteran_dependents,
        step_children: children[:step_children],
        user: @user
      ).create_all

      process_674(proc_id, dependents, payload)
    end

    def process_674(proc_id, dependents, payload)
      dependents.each do |dependent|
        if dependent_over_18_attending_school?(dependent[:type])
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
      vnp_response = bgs_service.create_proc
      bgs_service.create_proc_form(vnp_response[:vnp_proc_id])

      vnp_response[:vnp_proc_id]
    end

    def dependent_over_18_attending_school?(dependent_type)
      return true if dependent_type == '674'

      false
    end

    def bgs_service
      BGS::Service.new(@user)
    end
  end
end
