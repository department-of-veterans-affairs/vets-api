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
      # person_create_response = vnp_person_create(create_ptcpnt_response["vnp_ptcpnt_id"])
      # Step 5 Create address for veteran pass in VNP participant id created in step 3
      # vnp_ptcpnt_addrs_create_response = vnp_ptcpnt_addrs_create(create_ptcpnt_response["vnp_ptcpnt_id"])
      veteran_particpant = create_participant(proc_id, payload['veteran'])
      veteran = vnp_create(proc_id, veteran_particpant[:vnp_ptcpnt_id], @user.ssn)

      #####- loop through 6-8 for each dependent
      #   6. Create *NEXT* participant “Pass in corp participant id if it is obtainable”
      #   7. Create *Dependent* using participant-id from step 6
      #   8. Create address for dependent pass in participant-id from step 6
      #####

      # 9. Create Phone number for veteran or spouse(dependent?) pass in participant-id from step 3 or 6 (Maybe fire this off for each participant, we’ll look it up later)
      # vnp_ptcpnt_phone_create_response = vnp_ptcpnt_phone_create(create_ptcpnt_response["vnp_ptcpnt_id"])
      # vnp_ptcpnt_phone_create_response
      dependents = create_dependents(proc_id, payload)

      # 10. Create relationship pass in Veteran and dependent using respective participant-id (loop it for each dependent)
      vnp_relationship_create(proc_id, veteran, dependents)

      # ####-We’ll only do this for form number 674
      # 11. Create Child school (if there are kids)
      vnp_child_school_student(proc_id, dependents)
      # 12. Create Child student (if there are kids)

      ####- Back in 686
      # 13. Create benefit claims in formation (no mention of id)
      # 14. Insert vnp benefit claim (created in step 13?)
      # 15. Update vip benefit claims information (pass Corp benefit claim id Created in step 14)
      # 16. Set vnpProcstateTypeCd to “ready “
    end

    private

    def service
      @service ||= LighthouseBGS::Services.new(
        external_uid: @user.icn,
        external_key: @user.email
      )
    end

    def create_proc_id_and_form
      vnp_response = vnp_proc_create
      vnp_proc_form_create(vnp_response[:vnp_proc_id])

      vnp_response[:vnp_proc_id]
    end

    def vnp_proc_create
      service.vnp_proc_v2.vnp_proc_create(
        vnp_proc_type_cd: 'COMPCLM',
        vnp_proc_state_type_cd: 'Ready',
        creatd_dt: '2020-02-25T09:59:16-06:00',
        last_modifd_dt: '2020-02-25T10:02:28-06:00',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application,
        submtd_dt: '2020-02-25T10:01:59-06:00',
        ssn: @user.ssn
      )
    end

    def vnp_proc_form_create(vnp_proc_id)
      service.vnp_proc_form.vnp_proc_form_create(
        vnp_proc_id: vnp_proc_id,
        form_type_cd: '21-686c',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        ssn: @user.ssn
      )
    end

    def create_participant(proc_id, payload)
      service.vnp_ptcpnt.vnp_ptcpnt_create(
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id: '',
        fraud_ind: '',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: 'I',
        jrn_user_id: Settings.bgs.client_username,
        legacy_poa_cd: '',
        misc_vendor_ind: '',
        ptcpnt_short_nm: '',
        ptcpnt_type_nm: 'Person',
        tax_idfctn_nbr: '',
        tin_waiver_reason_type_cd: '',
        ptcpnt_fk_ptcpnt_id: '',
        #corp_ptcpnt_id: @user.participant_id,
        corp_ptcpnt_id: '',
        ssn: payload['ssn']
      )
    end

    def create_dependents(proc_id, payload)
      dependents = payload['veteran']['dependents'].map do |dependent|
        dependent_participant = create_participant(proc_id, dependent)
        vnp_create(proc_id, dependent_participant[:vnp_ptcpnt_id], @user.ssn)
        dependent_participant.merge!(dependent)
      end

      unless payload['veteran']['spouse'].blank?
        spouse_participant = create_participant(proc_id, payload['veteran']['spouse'])
        spouse = vnp_create(proc_id, spouse_participant[:vnp_ptcpnt_id], @user.ssn)
        spouse_participant.merge!(payload['veteran']['spouse'])
        dependents << spouse
      end

      dependents
    end

    def vnp_create(proc_id, participant_id, ssn)
      vnp_person_create(proc_id, participant_id, ssn)
      vnp_address_create(proc_id, participant_id, ssn)
      vnp_phone_create(proc_id, participant_id, ssn)
    end

    def vnp_person_create(proc_id, participant_id, ssn)
      service.vnp_person.vnp_person_create(
        vnp_ptcpnt_id: participant_id,
        birth_city_nm: "",
        birth_state_cd: "",
        birth_cntry_nm: "",
        cmptny_decn_type_cd: "",
        dep_nbr: "0",
        emp_ind: "",
        entlmt_type_cd: "",
        ethnic_type_cd: "",
        ever_maried_ind: "",
        fid_decn_categy_type_cd: "",
        file_nbr: "",
        first_nm: "Jane",
        first_nm_key: "",
        frgn_svc_nbr: "0",
        gender_cd: "F",
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        last_nm: "Smith",
        last_nm_key: "",
        lgy_entlmt_type_cd: "",
        martl_status_type_cd: "",
        middle_nm: "",
        mlty_person_ind: "",
        months_presnt_emplyr_nbr: "0",
        net_worth_amt: "0",
        no_ssn_reason_type_cd: "",
        ocptn_txt: "",
        person_death_cause_type_nm: "",
        person_type_nm: "",
        potntl_dngrs_ind: "",
        race_type_nm: "",
        serous_emplmt_hndcap_ind: "",
        slttn_type_nm: "",
        spina_bifida_ind: "",
        ssn_nbr: "",
        ssn_vrfctn_status_type_cd: "",
        suffix_nm: "",
        tax_abtmnt_cd: "",
        termnl_digit_nbr: "",
        title_txt: "",
        vet_ind: "",
        vet_type_nm: "",
        years_presnt_emplyr_nbr: "0",
        vnp_proc_id: proc_id,
        vnp_srusly_dsabld_ind: "",
        vnp_school_child_ind: "",
        ssn: ssn
      )
    end

    def vnp_address_create(proc_id, participant_id, ssn)
      service.vnp_ptcpnt_addrs.vnp_ptcpnt_addrs_create(
        efctv_dt: Time.current.iso8601,
        vnp_ptcpnt_id: participant_id,
        vnp_proc_id: proc_id,
        addrs_one_txt: '',
        addrs_three_txt: '',
        addrs_two_txt: '',
        bad_addrs_ind: '',
        city_nm: '',
        cntry_nm: '',
        county_nm: '',
        eft_waiver_type_nm: '',
        email_addrs_txt: '',
        end_dt: '',
        fms_addrs_code_txt: '',
        frgn_postal_cd: '',
        group1_verifd_type_cd: '',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        lctn_nm: '',
        mlty_postal_type_cd: '',
        mlty_post_office_type_cd: '',
        postal_cd: '',
        prvnc_nm: '',
        ptcpnt_addrs_type_nm: 'Mailing',
        shared_addrs_ind: 'N',
        trsury_addrs_five_txt: '',
        trsury_addrs_four_txt: '',
        trsury_addrs_one_txt: '',
        trsury_addrs_six_txt: '',
        trsury_addrs_three_txt: '',
        trsury_addrs_two_txt: '',
        trsury_seq_nbr: '',
        trtry_nm: '',
        zip_first_suffix_nbr: '',
        zip_prefix_nbr: '',
        zip_second_suffix_nbr: '',
        ssn: ssn
      )
    end

    def vnp_phone_create(proc_id, participant_id, ssn)
      service.vnp_ptcpnt_phone.vnp_ptcpnt_phone_create(
        vnp_ptcpnt_phone_id: '',
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id: participant_id,
        phone_type_nm: 'Nighttime',
        phone_nbr: '848-4848',
        efctv_dt: Time.current.iso8601,
        end_dt: '?',
        area_nbr: '984',
        cntry_nbr: '?',
        frgn_phone_rfrnc_txt: '?',
        extnsn_nbr: '?',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_user_id: Settings.bgs.client_username,
        jrn_status_type_cd: "U",
        jrn_obj_id: Settings.bgs.application,
        ssn: ssn
      )
    end

    def vnp_relationship_create(proc_id, veteran, dependents)
      dependents.map do |dependent|
        service.vnp_ptcpnt_rlnshp.vnp_ptcpnt_rlnshp_create(
          vnp_ptcpnt_rlnshp_id: "",
          begin_dt: "",
          child_prevly_married_ind: "",
          end_dt: "",
          event_dt: "",
          family_rlnshp_type_nm: "Spouse",
          fid_attntn_txt: "",
          hlthcr_prvdr_rlse_ind: "",
          jrn_dt: Time.current.iso8601,
          jrn_lctn_id: Settings.bgs.client_station_id,
          jrn_obj_id: Settings.bgs.application,
          jrn_status_type_cd: "U",
          jrn_user_id: Settings.bgs.client_username,
          lives_with_relatd_person_ind: "",
          marage_city_nm: "Philadelphia",
          marage_cntry_nm: "USA",
          marage_state_cd: "PA",
          marage_trmntn_city_nm: "",
          marage_trmntn_cntry_nm: "",
          marage_trmntn_state_cd: "",
          marage_trmntn_type_cd: "",
          mthly_support_from_vet_amt: "",
          proof_depncy_ind: "",
          prptnl_phrase_type_nm: "",
          ptcpnt_rlnshp_type_nm: "Spouse",
          rate_type_nm: "",
          review_dt: "",
          status_type_cd: "",
          temp_custdn_ind: "",
          poa_rep_nm: "",
          poa_rep_title_txt: "",
          poa_signtr_vrfctn_dt: "",
          poa_rep_type_cd: "",
          poa_agency_nm: "",
          vnp_proc_id: proc_id,
          vnp_ptcpnt_id_a: veteran[:vnp_ptcpnt_id],
          vnp_ptcpnt_id_b: dependent[:vnp_ptcpnt_id],
          ssn: @user.ssn
        )
      end
    end

    def vnp_child_school_student(proc_id, dependents)
      dependents.map do |dependent|
        if dependent["attendingSchool"]
          child_school_create(proc_id, dependent)
          vnp_child_student_create(proc_id, dependent)
        end
      end
    end

    def child_school_create(proc_id, dependent)
      service.vnp_child_school.child_school_create(
        vnp_proc_id: proc_id,
        vnp_child_school_id: "",
        course_name_txtame_txt: "Bachelors",
        curnt_hours_per_wk_num: "8",
        curnt_school_addrs_one_txt: "1585 E 13th Ave",
        curnt_school_addrs_two_txt: "",
        curnt_school_addrs_three_txt: "",
        curnt_school_addrs_zip_nbr: "97403",
        curnt_school_nm: "University of Oregon",
        curnt_school_postal_cd: "OR",
        curnt_sessns_per_wk_num: "4",
        current_edu_instn_ptcpnt_id: "",
        full_time_studnt_type_cd: "College",
        gradtn_dt: "2022-05-12T00:00:00-06:00",
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        last_term_start_dt: "",
        last_term_end_dt: "",
        last_term_enrlmt_ind: "",
        part_time_school_subjct_txt: "Biology",
        prev_hours_per_wk_num: "",
        prev_school_addrs_one_txt: "",
        prev_school_addrs_two_txt: "",
        prev_school_addrs_three_txt: "",
        prev_school_addrs_zip_nbr: "",
        prev_school_nm: "",
        prev_school_postal_cd: "",
        prev_sessns_per_wk_num: "",
        rmks: "",
        school_actual_expctd_start_dt: "",
        school_term_start_dt: "",
        vnp_ptcpnt_id: dependent[:vnp_ptcpnt_id],
        prev_edu_instn_ptcpnt_id: "",
        prev_school_city_nm: "",
        prev_school_cntry_nm: "",
        curnt_school_city_nm: "",
        curnt_school_cntry_nm: "",
        prev_mlty_postal_typ_cd: "",
        prev_mlty_post_office_typ_cd: "",
        prev_frgn_postal_cd: "",
        curnt_mlty_postal_typ_cd: "",
        curnt_mlty_post_office_typ_cd: "",
        curnt_forgn_postal_cd: "",
        ssn: @user.ssn
      )
    end

    def vnp_child_student_create(proc_id, dependent)
      service.vnp_child_student.child_student_create(
        vnp_proc_id: proc_id,
        vnp_ptcpnt_id: dependent[:vnp_ptcpnt_id],
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        agency_paying_tuitn_nm: "",
        govt_paid_tuitn_ind: "",
        govt_paid_tuitn_start_dt: "",
        marage_dt: "",
        next_year_annty_income_amt: "",
        next_year_emplmt_income_amt: "",
        next_year_other_income_amt: "",
        next_year_ssa_income_amt: "",
        other_asset_amt: "",
        real_estate_amt: "",
        rmks: "",
        saving_amt: "",
        stock_bond_amt: "",
        term_year_annty_income_amt: "",
        term_year_emplmt_income_amt: "",
        term_year_other_income_amt: "",
        term_year_ssa_income_amt: "",
        ssn: @user.ssn
      )
    end
  end
end

