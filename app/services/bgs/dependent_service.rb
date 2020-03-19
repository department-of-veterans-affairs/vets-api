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
      vnp_response = vnp_proc_create

      vnp_proc_id = vnp_response[:vnp_proc_id]

      create_proc_form_response = vnp_proc_form_create(vnp_proc_id)

      create_ptcpnt_response = vnp_ptcpnt_create

      person_create_response = vnp_person_create(create_ptcpnt_response["vnp_ptcpnt_id"])

      person_create_response
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
        jrn_lctn_id: Settings.bgs.jrn_lctn_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.jrn_user_id,
        jrn_obj_id: Settings.bgs.jrn_obj_id,
        submtd_dt: '2020-02-25T10:01:59-06:00',
        ssn: current_user.ssn
      )
    end

    def vnp_proc_form_create(vnp_proc_id)
      service.vnp_proc_form.vnp_proc_form_create(
        vnp_proc_id: vnp_proc_id,
        form_type_cd: '21-686c',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.jrn_lctn_id,
        jrn_obj_id: Settings.bgs.jrn_obj_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.jrn_user_id,
        ssn: current_user.ssn
      )
    end

    def vnp_ptcpnt_create
      service.vnp_ptcpnt.vnp_ptcpnt_create(
        vnp_ptcpnt_id: '',
        vnp_proc_id: '3826728',
        fraud_ind: '',
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.jrn_lctn_id,
        jrn_obj_id: Settings.bgs.jrn_obj_id,
        jrn_status_type_cd: 'I',
        jrn_user_id: Settings.bgs.jrn_user_id,
        legacy_poa_cd: '',
        misc_vendor_ind: '',
        ptcpnt_short_nm: '',
        ptcpnt_type_nm: 'Person',
        tax_idfctn_nbr: '',
        tin_waiver_reason_type_cd: '',
        ptcpnt_fk_ptcpnt_id: '',
        corp_ptcpnt_id: '600036507',
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
        jrn_lctn_id: Settings.bgs.jrn_lctn_id,
        jrn_obj_id: Settings.bgs.jrn_obj_id,
        jrn_status_type_cd: "U",
        jrn_user_id: Settings.bgs.jrn_user_id,
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
        vnp_proc_id: "3826728",
        vnp_srusly_dsabld_ind: "",
        vnp_school_child_ind: "",
        ssn: current_user.ssn
      )
    end
  end
end
