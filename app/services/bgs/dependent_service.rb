# frozen_string_literal: true

module BGS
  class DependentService < Base
    def initialize(user)
      @user = user
    end

    def get_dependents
      service
        .claimants
        .find_dependents_by_participant_id(
          @user.participant_id, @user.ssn
        )
    end

    def modify_dependents(params = nil)
      # delete_me_root = Rails.root.to_s
      # delete_me_payload_file = File.read("#{delete_me_root}/app/services/bgs/possible_payload_snake_case.json")
      # payload = JSON.parse(delete_me_payload_file)

      # Todo we should probably move the param serialization in dependents to here 🤔
      payload = params.to_h

      proc_id = create_proc_id_and_form
      veteran = VnpVeteran.new(proc_id: proc_id, payload: payload, user: @user).create
      dependents = Dependents.new(proc_id: proc_id, veteran: veteran, payload: payload, user: @user).create
      VnpRelationships.new(proc_id: proc_id, veteran: veteran, dependents: dependents, user: @user).create

      # # # ####-We’ll only do this for form number 674
      # # # create_child_school_student(proc_id, dependents)

      vnp_benefit_claim = VnpBenefitClaim.new(proc_id: proc_id, veteran: veteran, user: @user)
      vnp_benefit_claim_record = vnp_benefit_claim.create

      benefit_claim_record = BenefitClaim.new(vnp_benefit_claim: vnp_benefit_claim_record, veteran: veteran, user: @user).create
      vnp_benefit_claim.update(benefit_claim_record, vnp_benefit_claim_record)
      update_proc(proc_id)
    end

    private

    def create_proc_id_and_form
      vnp_response = create_proc
      create_proc_form(vnp_response[:vnp_proc_id])

      vnp_response[:vnp_proc_id]
    end

    # def create_child_school_student(proc_id, dependents)
    #   dependents.map do |dependent|
    #     if dependent["attendingSchool"]
    #       create_child_school(proc_id, dependent)
    #       create_child_student(proc_id, dependent)
    #     end
    #   end
    # end
    #
    # def create_child_school(proc_id, dependent)
    #   service.vnp_child_school.child_school_create(
    #     vnp_proc_id: proc_id,
    #     jrn_dt: Time.current.iso8601,
    #     jrn_lctn_id: Settings.bgs.client_station_id,
    #     jrn_obj_id: Settings.bgs.application,
    #     jrn_status_type_cd: "U",
    #     jrn_user_id: Settings.bgs.client_username,
    #     vnp_ptcpnt_id: dependent[:vnp_ptcpnt_id],
    #     gradtn_dt: dependent[:school_info][:graduation_date],
    #     ssn: @user.ssn # Just here to make the mocks work
    #   )
    # end

    # def create_child_student(proc_id, dependent)
    #   service.vnp_child_student.child_student_create(
    #     vnp_proc_id: proc_id,
    #     vnp_ptcpnt_id: dependent[:vnp_ptcpnt_id],
    #     jrn_dt: Time.current.iso8601,
    #     jrn_lctn_id: Settings.bgs.client_station_id,
    #     jrn_obj_id: Settings.bgs.application,
    #     jrn_status_type_cd: "U",
    #     jrn_user_id: Settings.bgs.client_username,
    #     ssn: @user.ssn # Just here to make the mocks work
    #   )
    # end
  end
end

