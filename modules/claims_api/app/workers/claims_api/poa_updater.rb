# frozen_string_literal: true

require 'sidekiq'
require 'lighthouse_bgs'

module ClaimsApi
  class PoaUpdater
    include Sidekiq::Worker

    def perform(power_of_attorney_id)
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      service = LighthouseBGS::Services.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )
      response = service.vet_record.update_birls_record(
        ssn: poa_form.auth_headers['va_eauth_pnid'],
        poa_code: poa_form.form_data['poaCode']
      )

      poa_form.status = if response[:return_code] == 'BMOD0001'
                          ClaimsApi::PowerOfAttorney::UPDATED
                        else
                          ClaimsApi::PowerOfAttorney::ERRORED
                        end

      poa_form.save
    end
  end
end
