# frozen_string_literal: true

require 'sidekiq'
require 'bgs'
require 'claims_api/claim_logger'

module ClaimsApi
  class PoaVBMSUpdater
    include Sidekiq::Worker

    def perform(power_of_attorney_id) # rubocop:disable Metrics/MethodLength
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      service = BGS::Services.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )

      ClaimsApi::Logger.log(
        'poa',
        poa_id: power_of_attorney_id,
        detail: 'Updating Access',
        poa_code: poa_form.form_data.dig('serviceOrganization', 'poaCode')
      )

      response = service.corporate_update.update_poa_access(
        participant_id: poa_form.auth_headers['va_eauth_pid'],
        poa_code: poa_form.form_data.dig('serviceOrganization', 'poaCode'),
        allow_poa_access: 'y',
        allow_poa_c_add: allow_address_change?(poa_form, power_of_attorney_id) ? 'y' : 'n'
      )

      if response[:return_code] == 'GUIE50000'
        poa_form.status = ClaimsApi::PowerOfAttorney::UPDATED
        poa_form.vbms_error_message = nil if poa_form.vbms_error_message.present?
        ClaimsApi::Logger.log('poa', poa_id: power_of_attorney_id, detail: 'VBMS Success')
      else
        poa_form.vbms_error_message = 'update_poa_access failed with code '\
                                      "#{response[:return_code]}: #{response[:return_message]}"
        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        ClaimsApi::Logger.log('poa',
                              poa_id: power_of_attorney_id,
                              detail: 'VBMS Failed',
                              error: response[:return_message])
      end

      poa_form.save
    end

    def allow_address_change?(poa_form, power_of_attorney_id)
      ClaimsApi::Logger.log('poa', poa_id: power_of_attorney_id, detail: 'consent to change address has changed')
      poa_form.form_data['consentAddressChange']
    end
  end
end
