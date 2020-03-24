# frozen_string_literal: true

module BGS
  class DependentService
    def initialize(current_user)
      @current_user = current_user
      @service = LighthouseBGS::Services.new(
        external_uid: current_user.icn,
        external_key: current_user.email
      )
    end

    def get_dependents
      service
      .claimants
      .find_dependents_by_participant_id(
        current_user.participant_id, current_user.ssn
      )
    end

    def modify_dependents
      # Step 1 create Proc
      vnp_response = vnp_proc_create

      @vnp_proc_id = vnp_response[:vnp_proc_id]
      # Step 2 Create ProcForm using ProcId from Step 1
      create_proc_form_response = vnp_proc_form_create

      # Step 3 Create FIRST Participant
      create_ptcpnt_response = vnp_ptcpnt_create

      # Step 4 Create "Veteran" this is a 'Person' using ParticipantId generated from Step 3
      person_create_response = vnp_person_create(create_ptcpnt_response["vnp_ptcpnt_id"])

      # Step 5 Create address for veteran pass in VNP participant id created in step 3
      vnp_ptcpnt_addrs_create_response = vnp_ptcpnt_addrs_create(create_ptcpnt_response["vnp_ptcpnt_id"])

      #####- loop through 6-8 for each dependent
      #   6. Create *NEXT* participant “Pass in corp participant id if it is obtainable”
      #   7. Create *Dependent* using participant-id from step 6
      #   8. Create address for dependent pass in participant-id from step 6
      #####

      # 9. Create Phone number for veteran or spouse(dependent?) pass in participant-id from step 3 or 6 (Maybe fire this off for each participant, we’ll look it up later)
      vnp_ptcpnt_phone_create_response = vnp_ptcpnt_phone_create(create_ptcpnt_response["vnp_ptcpnt_id"])

      vnp_ptcpnt_phone_create_response

      # 10. Create relationship pass in Veteran and dependent using respective participant-id (loop it for each dependent)

      # ####-We’ll only do this for form number 674
      # 11. Create Child school (if there are kids)
      # 12. Create Child student (if there are kids)

      ####- Back in 686
      # 13. Create benefit claims in formation (no mention of id)
      # 14. Insert vnp benefit claim (created in step 13?)
      # 15. Update vip benefit claims information (pass Corp benefit claim id Created in step 14)
      # 16. Set vnpProcstateTypeCd to “ready “
    end

    private

    attr_reader :current_user, :service

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
        ssn: current_user.ssn
      )
    end

    def vnp_proc_form_create
      service.vnp_proc_form.vnp_proc_form_create(
        vnp_proc_id: @vnp_proc_id,
        form_type_cd: '21-686c',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        ssn: current_user.ssn
      )
    end

    def vnp_ptcpnt_create
      service.vnp_ptcpnt.vnp_ptcpnt_create(
        vnp_ptcpnt_id: '',
        vnp_proc_id: @vnp_proc_id,
        fraud_ind: '',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        legacy_poa_cd: '',
        misc_vendor_ind: '',
        ptcpnt_short_nm: '',
        ptcpnt_type_nm: 'Person',
        tax_idfctn_nbr: '',
        tin_waiver_reason_type_cd: '',
        ptcpnt_fk_ptcpnt_id: '',
        corp_ptcpnt_id: current_user.participant_id,
        ssn: current_user.ssn
      )
    end

    def vnp_person_create(vnp_ptcpnt_id)
      service.vnp_person.vnp_person_create(
        vnp_ptcpnt_id: vnp_ptcpnt_id,
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
        frgn_svc_nbr: "0",
        gender_cd: "F",
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_obj_id: Settings.bgs.application,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.client_username,
        last_nm: "Smith",
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
        ssn_nbr: "333224444",
        ssn_vrfctn_status_type_cd: "",
        suffix_nm: "",
        tax_abtmnt_cd: "",
        termnl_digit_nbr: "",
        title_txt: "",
        vet_ind: "",
        vet_type_nm: "",
        years_presnt_emplyr_nbr: "0",
        vnp_proc_id: @vnp_proc_id,
        vnp_srusly_dsabld_ind: "",
        vnp_school_child_ind: "",
        ssn: current_user.ssn
      )
    end

    def vnp_ptcpnt_addrs_create(vnp_ptcpnt_id)
      service.vnp_ptcpnt_addrs.vnp_ptcpnt_addrs_create(
        vnp_ptcpnt_id: vnp_ptcpnt_id,
        vnp_proc_id: @vnp_proc_id,
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
        ssn: current_user.ssn
      )
    end

    def vnp_ptcpnt_phone_create(vnp_ptcpnt_id)
      service.vnp_ptcpnt_phone.vnp_ptcpnt_phone_create(
        vnp_ptcpnt_phone_id: '',
        vnp_proc_id: @vnp_proc_id,
        vnp_ptcpnt_id: vnp_ptcpnt_id,
        phone_type_nm: 'Nighttime',
        phone_nbr: '848-4848',
        efctv_dt:'2011-09-19T13:56:01-05:00',
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
        ssn: current_user.ssn
      )
    end
  end
end

