# frozen_string_literal: true

module BGS
  class DependentService
    def get_dependents(current_user)
      service = LighthouseBGS::Services.new(
        external_uid: current_user.icn,
        external_key: current_user.email
      )

      service.claimants.find_dependents_by_participant_id(current_user.participant_id, current_user.ssn)
    end

    def modify_dependents(current_user)
      service = LighthouseBGS::Services.new(
        external_uid: current_user.icn,
        external_key: current_user.email
      )

      vnpResponse = service.vnp_proc_v2.vnp_proc_create(
        vnp_proc_type_cd: 'COMPCLM',
        vnp_proc_state_type_cd: 'Ready',
        creatd_dt: '2020-02-25T09:59:16-06:00',
        last_modifd_dt: '2020-02-25T10:02:28-06:00',
        jrn_dt: '2020-02-25T10:02:31-06:00',
        jrn_lctn_id: '281',
        jrn_status_type_cd: 'U',
        jrn_user_id: 'VAgovAPI',
        jrn_obj_id: 'VAgovAPI',
        submtd_dt: '2020-02-25T10:01:59-06:00',
        ssn: current_user.ssn)


      vnp_proc_id = vnpResponse[:vnp_proc_id]

      service.vnp_proc_form.vnp_proc_form_create(
        vnp_proc_id: vnp_proc_id,
        form_type_cd: '21-686c',
        jrn_dt: '2020-02-25T10:02:31-06:00',
        jrn_lctn_id: '281',
        jrn_obj_id: 'VAgovAPI',
        jrn_status_type_cd: 'U',
        jrn_user_id: 'VAgovAPI',
        ssn: current_user.ssn)


    end
  end
end
