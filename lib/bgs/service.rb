# frozen_string_literal: true

module BGS
  class Service
    def initialize(user)
      @user = user
    end

    def vnp_create_benefit_claim(vnp_benefit_params)
      service.vnp_bnft_claim.vnp_bnft_claim_create(vnp_benefit_params.merge(bgs_auth))
    end

    def vnp_benefit_claim_update(vnp_benefit_params)
      service.vnp_bnft_claim.vnp_bnft_claim_update(vnp_benefit_params.merge(bgs_auth))
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
