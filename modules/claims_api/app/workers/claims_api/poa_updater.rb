# frozen_string_literal: true

require 'sidekiq'
require 'bgs'

module ClaimsApi
  class PoaUpdater
    include Sidekiq::Worker

    def perform(power_of_attorney_id)
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      service = BGS::Services.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )
      response = service.vet_record.update_birls_record(
        ssn: poa_form.auth_headers['va_eauth_pnid'],
        poa_code: poa_form.form_data['serviceOrganization']['poaCode']
      )

      if response[:return_code] == 'BMOD0001'
        poa_form.status = ClaimsApi::PowerOfAttorney::UPDATED

        if enable_vbms_access?(poa_form: poa_form)
          veteran_participant_id = poa_form.auth_headers['va_eauth_pid']
          ClaimsApi::VBMSUpdater.perform_async(poa_form.id, veteran_participant_id)
        end
      else
        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        poa_form.vbms_error_message = "BGS Error: update_birls_record failed with code #{response[:return_code]}"
      end

      poa_form.save
    end

    private

    def enable_vbms_access?(poa_form:)
      poa_form.form_data['recordConsent'] && poa_form.form_data['consentLimits'].blank?
    end
  end
end
