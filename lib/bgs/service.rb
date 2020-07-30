# frozen_string_literal: true

module BGS
  class Service
    def initialize(user)
      @user = user
    end

    def create_participant(proc_id, corp_ptcpnt_id = nil)
      service.vnp_ptcpnt.vnp_ptcpnt_create(
        { vnp_proc_id: proc_id, ptcpnt_type_nm: 'Person', corp_ptcpnt_id: corp_ptcpnt_id }.merge(bgs_auth)
      )
    end

    def create_person(person_params)
      service.vnp_person.vnp_person_create(person_params.merge(bgs_auth))
    end

    def create_address(address_params)
      service.vnp_ptcpnt_addrs.vnp_ptcpnt_addrs_create(
        address_params.merge(bgs_auth)
      )
    end

    def create_phone(proc_id, participant_id, payload)
      service.vnp_ptcpnt_phone.vnp_ptcpnt_phone_create(
        {
          vnp_proc_id: proc_id,
          vnp_ptcpnt_id: participant_id,
          phone_type_nm: 'Daytime',
          phone_nbr: payload['phone_number'],
          efctv_dt: Time.current.iso8601
        }.merge(bgs_auth)
      )
    end

    def find_benefit_claim_type_increment
      service.data.find_benefit_claim_type_increment(
        {
          ptcpnt_id: @user[:participant_id],
          bnft_claim_type_cd: '130DPNEBNADJ',
          pgm_type_cd: 'CPL',
          ssn: @user[:ssn] # Just here to make the mocks work
        }
      )
    end

    def get_va_file_number
      person = service.people.find_person_by_ptcpnt_id(@user[:participant_id])

      person[:file_nbr]
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
