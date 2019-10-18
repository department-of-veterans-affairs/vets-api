# frozen_string_literal: true

require 'sidekiq'
require 'lighthouse-bgs'

module ClaimsApi
  class PoaUpdater
    include Sidekiq::Worker

    def perform(power_of_attorney_id)
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      service = LighthouseBGS::Services.new
      response = service.vet_record.update_birls_record(
        ssn: poa_form.auth_headers['X-VA-SSN'],
        poa_code: poa_form.form_data['poaCode']
      )

      poa_form.status = if response['return_code'] == 'BMOD0001'
                          ClaimsApi::PowerOfAttorney::UPDATED
                        else
                          ClaimsApi::PowerOfAttorney::ERRORED
                        end

      poa_form.save
    end
  end
end
