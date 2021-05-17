# frozen_string_literal: true

require 'sidekiq'
require 'bgs'

module ClaimsApi
  class VBMSUpdater
    include Sidekiq::Worker

    def perform(power_of_attorney_id, target_veteran)
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      service = BGS::Services.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )
      service.corporate_update.update_poa_access(
        participant_id: target_veteran.participant_id,
        poa_code: poa_form.form_data.dig('serviceOrganization', 'poaCode'),
        allow_poa_access: 'y',
        allow_poa_c_add: 'y'
      )
    end
  end
end
