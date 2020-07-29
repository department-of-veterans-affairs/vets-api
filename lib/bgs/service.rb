# frozen_string_literal: true

module BGS
  class Service
    include BGS::Exceptions::BGSErrors

    def initialize(user)
      @user = user
    end

    # def create_proc
    #   with_multiple_attempts_enabled do
    #     service.vnp_proc_v2.vnp_proc_create(
    #       { vnp_proc_type_cd: 'DEPCHG', vnp_proc_state_type_cd: 'Started' }.merge(bgs_auth)
    #     )
    #   end
    # end
    #
    # def create_proc_form(vnp_proc_id)
    #   with_multiple_attempts_enabled do
    #     service.vnp_proc_form.vnp_proc_form_create(
    #       { vnp_proc_id: vnp_proc_id,  form_type_cd: '21-686c' }.merge(bgs_auth)
    #     )
    #   end
    # end
    #
    # def create_participant(proc_id, corp_ptcpnt_id = nil)
    #   with_multiple_attempts_enabled do
    #     service.vnp_ptcpnt.vnp_ptcpnt_create(
    #       { vnp_proc_id: proc_id, ptcpnt_type_nm: 'Person', corp_ptcpnt_id: corp_ptcpnt_id }.merge(bgs_auth)
    #     )
    #   end
    # end
    #
    # def create_person(person_params)
    #   with_multiple_attempts_enabled do
    #     service.vnp_person.vnp_person_create(person_params.merge(bgs_auth))
    #   end
    # end

    def create_relationship(relationship_params)
      service.vnp_ptcpnt_rlnshp.vnp_ptcpnt_rlnshp_create(relationship_params.merge(bgs_auth))
    end

    def bgs_auth
      {
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application,
        ssn: @user[:ssn] # Just here to make the mocks work
      }
    end

    private

    def service
      @service ||= BGS::Services.new(external_uid: @user[:icn], external_key: @user[:external_key])
    end
  end
end
