# frozen_string_literal: true

require_relative 'benefit_claim'
require_relative 'dependents'
require_relative 'service'
require_relative 'student_school'
require_relative 'vnp_benefit_claim'
require_relative 'vnp_relationships'
require_relative 'vnp_veteran'
require_relative 'dependent_higher_ed_attendance'

module BGS
  class Form674
    def initialize(user)
      @user = user
    end

    def submit(payload)
      proc_id = create_proc_id_and_form
      veteran = VnpVeteran.new(proc_id: proc_id, payload: payload, user: @user, claim_type: '130SCHATTEBN').create

      process_relationships(proc_id, veteran, payload)

      vnp_benefit_claim = VnpBenefitClaim.new(proc_id: proc_id, veteran: veteran, user: @user)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      benefit_claim_record = BenefitClaim.new(
        args: {
          vnp_benefit_claim: vnp_benefit_claim_record,
          veteran: veteran,
          user: @user,
          proc_id: proc_id,
          end_product_name: '130 - Automated School Attendance 674',
          end_product_code: '130SCHATTEBN'
        }
      ).create

      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
      bgs_service.update_proc(proc_id)
    end

    private

    def process_relationships(proc_id, veteran, payload)
      dependent = DependentHigherEdAttendance.new(proc_id: proc_id, payload: payload, user: @user).create

      VnpRelationships.new(
        proc_id: proc_id,
        veteran: veteran,
        dependents: [dependent],
        step_children: [],
        user: @user
      ).create_all

      process_674(proc_id, dependent, payload)
    end

    def process_674(proc_id, dependent, payload)
      StudentSchool.new(
        proc_id: proc_id,
        vnp_participant_id: dependent[:vnp_participant_id],
        payload: payload,
        user: @user
      ).create
    end

    def create_proc_id_and_form
      vnp_response = bgs_service.create_proc
      bgs_service.create_proc_form(
        vnp_response[:vnp_proc_id],
        '21-674'
      )

      vnp_response[:vnp_proc_id]
    end

    def bgs_service
      BGS::Service.new(@user)
    end
  end
end
