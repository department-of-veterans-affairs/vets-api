# frozen_string_literal: true

module BGS
  class Service
    include BGS::Exceptions::BGSErrors

    def initialize(user)
      @user = user
    end

    def insert_benefit_claim(benefit_claim_params)
      service.claims.insert_benefit_claim(benefit_claim_params)
    end

    def update_manual_proc(proc_id)
      service.vnp_proc_v2.vnp_proc_update(
        {vnp_proc_id: proc_id, vnp_proc_state_type_cd: 'Manual'}.merge(bgs_auth)
      )
    rescue => e
      notify_of_service_exception(e, __method__)
    end

    private

    def service
      @service ||= BGS::Services.new(external_uid: @user[:icn], external_key: @user[:external_key])
    end
  end
end