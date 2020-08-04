# frozen_string_literal: true

module BGS
  class Service
    # Journal Status Type Code
    # The alphabetic character representing the last action taken on the record
    # (I = Input, U = Update, D = Delete)
    JOURNAL_STATUS_TYPE_CODE = 'U'
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
    
    def vnp_create_benefit_claim(vnp_benefit_params)
      service.vnp_bnft_claim.vnp_bnft_claim_create(vnp_benefit_params.merge(bgs_auth))
    end

    def vnp_benefit_claim_update(vnp_benefit_params)
      service.vnp_bnft_claim.vnp_bnft_claim_update(vnp_benefit_params.merge(bgs_auth))
    end

    def create_relationship(relationship_params)
      service.vnp_ptcpnt_rlnshp.vnp_ptcpnt_rlnshp_create(relationship_params.merge(bgs_auth))
    end

    def bgs_auth
      {
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: JOURNAL_STATUS_TYPE_CODE,
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
