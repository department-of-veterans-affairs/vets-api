# frozen_string_literal: true

module BGS
  class DependentService
    def initialize(user)
      @user = user
    end

    def get_dependents
      service
        .claimants
        .find_dependents_by_participant_id(
          user.participant_id, user.ssn
        )
    end

    def modify_dependents
        delete_me_root = Rails.root.to_s
        delete_me_payload_file = File.read("#{delete_me_root}/app/services/bgs/possible_payload.json")
        payload = JSON.parse(delete_me_payload_file)

        # Step 1 create Proc
        # Step 2 Create ProcForm using ProcId from Step 1
        proc_id = create_proc_id_and_form

        # Step 3 Create FIRST Participant
        # Step 4 Create "Veteran" this is a 'Person' using ParticipantId generated from Step 3
        # Step 5 Create address for veteran pass in VNP participant id created in step 3
# veteran_particpant = create_participant(proc_id, payload['veteran'])
# create_person_address_phone(proc_id, veteran_particpant[:vnp_ptcpnt_id], payload['veteran'])

        #####- loop through 6-8 for each dependent
        #   6. Create *NEXT* participant “Pass in corp participant id if it is obtainable”
        #   7. Create *Dependent* using participant-id from step 6
        #   8. Create address for dependent pass in participant-id from step 6
        #####

# dependents = create_dependents(proc_id, payload)

        # 10. Create relationship pass in Veteran and dependent using respective participant-id (loop it for each dependent)
# create_relationship(proc_id, veteran_particpant, dependents)

        ####-We’ll only do this for form number 674
        # 11. Create Child school (if there are kids)
        # 12. Create Child student (if there are kids)
# create_child_school_student(proc_id, dependents)

        ####- Back in 686
        # 13. Create benefit claims in formation
# vnp_benefit_claim = create_benefit_claim(proc_id, veteran_particpant)

        # 14. Insert vnp benefit claim (created in step 13?)
# benefit_claim = insert_benefit_claim(vnp_benefit_claim, payload['veteran'])
# benefit_claim_record = benefit_claim[:benefit_claim_record]

        # 15. Update vnp benefit claims information (pass Corp benefit claim id Created in step 14)
  # bnft_update = vnp_bnft_claim_update(proc_id, benefit_claim_record, vnp_benefit_claim)
  # bnft_update
        # 16. Set vnpProcstateTypeCd to “ready “
        proc_update(proc_id)
    end

    private

    def service
      @service ||= LighthouseBGS::Services.new(
        external_uid: @user.icn,
        external_key: @user.email
      )
    end

    def create_proc_id_and_form
      vnp_response = create_proc
      create_proc_form(vnp_response[:vnp_proc_id])

      vnp_response[:vnp_proc_id]
    end

    def create_proc
      service.vnp_proc_v2.vnp_proc_create(
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application,
        ssn: @user.ssn # Just here to make the mocks work
      )
    end

    def create_proc_form(vnp_proc_id)
      service.vnp_proc_form.vnp_proc_form_create(
        vnp_proc_id: vnp_proc_id,
        form_type_cd: '21-686c',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        ssn: @user.ssn # Just here to make the mocks work
      )
    end

    def create_participant(proc_id, payload)
      service.vnp_ptcpnt.vnp_ptcpnt_create(
        vnp_proc_id: proc_id,
        ptcpnt_type_nm: 'Person', # Hard-coded intentionally
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: 'I', # Why is this 'I' it's 'U' other places
        jrn_user_id: Settings.bgs.client_username,
        ssn: payload['ssn'] # Just here to make mocks work
      )
    end

    def create_person(proc_id, participant_id, payload)
      service.vnp_person.vnp_person_create(
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id: participant_id,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        first_nm: payload['first_name'],
        last_nm: payload['last_name'],
        ssn: @user.ssn # Just here to make mocks work
      )
    end

    def create_dependents(proc_id, payload)
      dependents = payload['veteran']['dependents'].map do |dependent|
        dependent_participant = create_participant(proc_id, dependent)
        create_person_address_phone(proc_id, dependent_participant[:vnp_ptcpnt_id], dependent)
        dependent_participant.merge!(dependent).with_indifferent_access
      end

      unless payload['veteran']['spouse'].blank?
        spouse_participant = create_participant(proc_id, payload['veteran']['spouse'])
        create_person_address_phone(proc_id, spouse_participant[:vnp_ptcpnt_id], payload['veteran']['spouse'])
        spouse_participant.merge!(payload['veteran']['spouse'])
        dependents << spouse_participant.with_indifferent_access
      end

      dependents
    end

    def create_person_address_phone(proc_id, participant_id, payload)
      create_person(proc_id, participant_id, payload)
      create_address(proc_id, participant_id, payload)
      create_phone(proc_id, participant_id, payload)
    end

    def create_address(proc_id, participant_id, payload)
      service.vnp_ptcpnt_addrs.vnp_ptcpnt_addrs_create(
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        efctv_dt: Time.current.iso8601,
        vnp_ptcpnt_id: participant_id,
        vnp_proc_id: proc_id,
        ptcpnt_addrs_type_nm: 'Mailing',
        shared_addrs_ind: 'N',
        ssn: @user.ssn # Just here to make the mocks work
      )
    end

    def create_phone(proc_id, participant_id, payload)
      service.vnp_ptcpnt_phone.vnp_ptcpnt_phone_create(
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id: participant_id,
        phone_type_nm: 'Nighttime',
        phone_nbr: payload['phone'],
        efctv_dt: Time.current.iso8601,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_user_id: Settings.bgs.client_username,
        jrn_status_type_cd: "U",
        jrn_obj_id: Settings.bgs.application,
        ssn: @user.ssn # Just here to make the mocks work
      )
    end

    def create_relationship(proc_id, veteran, dependents)
      dependents.map do |dependent|
        service.vnp_ptcpnt_rlnshp.vnp_ptcpnt_rlnshp_create(
          vnp_proc_id: proc_id,
          vnp_ptcpnt_id_a: veteran[:vnp_ptcpnt_id],
          vnp_ptcpnt_id_b: dependent[:vnp_ptcpnt_id],
          ptcpnt_rlnshp_type_nm: dependent[:type],
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          ssn: @user.ssn # Just here to make mocks work
        )
      end
    end

    def create_child_school_student(proc_id, dependents)
      dependents.map do |dependent|
        if dependent["attendingSchool"]
          create_child_school(proc_id, dependent)
          create_child_student(proc_id, dependent)
        end
      end
    end

    def create_child_school(proc_id, dependent)
      service.vnp_child_school.child_school_create(
        vnp_proc_id: proc_id,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        vnp_ptcpnt_id: dependent[:vnp_ptcpnt_id],
        gradtn_dt: dependent[:school_info][:graduation_date],
        ssn: @user.ssn # Just here to make the mocks work
      )
    end

    def create_child_student(proc_id, dependent)
      service.vnp_child_student.child_student_create(
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id: dependent[:vnp_ptcpnt_id],
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        ssn: @user.ssn # Just here to make the mocks work
      )
    end

    def create_benefit_claim(proc_id, veteran_particpant)
      service.vnp_bnft_claim.vnp_bnft_claim_create(
        vnp_proc_id: proc_id,
        claim_rcvd_dt: Time.current.iso8601,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
         # not sure what this is. Is this just passed in bc this will be created when we fire this call?
        status_type_cd: "PEND", # not sure what this is marking it pending since we're creating it now
        svc_type_cd: "CP", # not sure what this is all records that I scanned had 'CP' here
        pgm_type_cd: "COMP", # This is either 'COMP' or 'CPL' from what I scanned
        bnft_claim_type_cd: "130PDA", # Cannot be null using 686c code provided does not work bc it is past the 12 character limit
        ptcpnt_clmant_id: veteran_particpant[:vnp_ptcpnt_id],
        claim_jrsdtn_lctn_id: "347", # Not required but cannot be null all records seem to be in the 300's and the same as the below
        intake_jrsdtn_lctn_id: "347", # Not required but cannot be null all records seem to be in the 300's
        ssn: @user.ssn # I think this is just for mocks
      )
    end

    # 'end_product' needs to be unique; end_product_code seems to be the claimTypeCode
    # HEY we were using 796149080 as file_number and ssn to make it work. Changed it to get the mock response working
    # We get "index for PL/SQL table out of range for host" when we try to use the user's ssn in file_number
    def insert_benefit_claim(vnp_benefit_claim, veteran_payload)
      service.benefit_claim_web.insert_benefit_claim(
        file_number: "796149080", # not convinced this is needed
        ssn: @user.ssn, # this is actually needed for the service call
        benefit_claim_type: "1", # this is intentionally hard coded
        payee: "00", # intentionally left hard-coded
        end_product_code: vnp_benefit_claim[:bnft_claim_type_cd],
        end_product: "475", # not sure what this is, it has to be unique tried this: vnp_benefit_claim[:vnp_bnft_claim_id] I just add one everytime I run this code
        first_name: @user.first_name,
        last_name: @user.last_name,
        city: veteran_payload["address"]["city"],
        state: veteran_payload["address"]["state"],
        postal_code: veteran_payload["address"]["postal_code"],
        country: veteran_payload["address"]["country"],
        disposition: "M", # intentionally left hard-coded
        section_unit_no: "555", # "VA office code". Not sure how reliable this is. Could throw undefined method for nil error super easy. Maybe we'll get it from the FE
        folder_with_claim: "N", # intentionally left hard-coded
        end_product_name: "endProductNameTest", # not sure what this is
        pre_discharge_indicator: "N", # intentionally left hard-coded
        date_of_claim: Time.current.strftime("%m/%d/%Y")
      )
    end

    def vnp_bnft_claim_update(proc_id, benefit_claim_record, vnp_benefit_claim)
      service.vnp_bnft_claim.vnp_bnft_claim_update(
        vnp_bnft_claim_id: vnp_benefit_claim[:vnp_bnft_claim_id],
        bnft_claim_type_cd: benefit_claim_record[:claim_type_code],
        claim_rcvd_dt: Time.current.iso8601,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        bnft_claim_id: benefit_claim_record[:benefit_claim_id],
        intake_jrsdtn_lctn_id: vnp_benefit_claim[:intake_jrsdtn_lctn_id],
        claim_jrsdtn_lctn_id: vnp_benefit_claim[:claim_jrsdtn_lctn_id],
        jrn_status_type_cd: benefit_claim_record[:journal_status_type_code],
        jrn_user_id: benefit_claim_record[:journal_user_id],
        pgm_type_cd: benefit_claim_record[:program_type_code],
        ptcpnt_clmant_id: vnp_benefit_claim[:ptcpnt_clmant_id],
        status_type_cd: benefit_claim_record[:status_type_code],
        svc_type_cd: benefit_claim_record[:service_type_code],
        vnp_proc_id: proc_id,
        ssn: @user.ssn # Just here to make mocks work
      )
    end

    def proc_update(proc_id)
      service.vnp_proc_v2.vnp_proc_create(
        vnp_proc_id: proc_id,
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        vnp_proc_state_type_cd: "Ready",
        ssn: @user.ssn
      )
    end
  end
end

