module BGS
  class PersonEntity
    attr_reader :type, :participant

    def initialize(details, client, user, proc_id, type = :dependent)
      @details = details
      @client = client
      @user = user
      @proc_id = proc_id
      @type = type
      @participant = create_participant
    end

    def vnp_create
      vnp_person_create(@participant[:vnp_ptcpnt_id])
      vnp_address_create(@participant[:vnp_ptcpnt_id])
      vnp_phone_create(@participant[:vnp_ptcpnt_id])
    end

    private

    def create_participant
      @client.vnp_ptcpnt.vnp_ptcpnt_create(
        vnp_ptcpnt_id: '',
        vnp_proc_id: @proc_id,
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
        corp_ptcpnt_id: @user.participant_id,
        ssn: @details['ssn']
      )
    end

    def vnp_person_create(vnp_ptcpnt_id)
      @client.vnp_person.vnp_person_create(
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
        ssn_nbr: "333224444",
        ssn_vrfctn_status_type_cd: "",
        suffix_nm: "",
        tax_abtmnt_cd: "",
        termnl_digit_nbr: "",
        title_txt: "",
        vet_ind: "",
        vet_type_nm: "",
        years_presnt_emplyr_nbr: "0",
        vnp_proc_id: @proc_id,
        vnp_srusly_dsabld_ind: "",
        vnp_school_child_ind: "",
        ssn: @details['ssn']
      )
    end

    def vnp_address_create(vnp_ptcpnt_id)
      @client.vnp_ptcpnt_addrs.vnp_ptcpnt_addrs_create(
        efctv_dt: Time.current.iso8601,
        vnp_ptcpnt_id: vnp_ptcpnt_id,
        vnp_proc_id: @proc_id,
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
        ssn: @details['ssn']
      )
    end

    def vnp_phone_create(vnp_ptcpnt_id)
      @client.vnp_ptcpnt_phone.vnp_ptcpnt_phone_create(
        vnp_ptcpnt_phone_id: '',
        vnp_proc_id: @proc_id,
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
        ssn: @details['ssn']
      )
    end
  end
end
