# frozen_string_literal: true

require 'sidekiq'
require 'bgs'
require 'claims_api/claim_logger'

module ClaimsApi
  class PoaUpdater
    include Sidekiq::Worker

    def perform(power_of_attorney_id) # rubocop:disable Metrics/MethodLength
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      service = BGS::Services.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )

      ssn = poa_form.auth_headers['va_eauth_pnid']
      file_number = service.people.find_by_ssn(ssn)[:file_nbr] # rubocop:disable Rails/DynamicFindBy

      response = service.vet_record.update_birls_record(
        file_number:,
        ssn:,
        poa_code: poa_form.form_data['serviceOrganization']['poaCode']
      )

      if response[:return_code] == 'BMOD0001'
        poa_form.status = ClaimsApi::PowerOfAttorney::UPDATED
        # Clear out the error message if there were previous failures
        poa_form.vbms_error_message = nil if poa_form.vbms_error_message.present?

        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Success')

        ClaimsApi::PoaVBMSUpdater.perform_async(poa_form.id) if enable_vbms_access?(poa_form:)
      else
        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        poa_form.vbms_error_message = "BGS Error: update_birls_record failed with code #{response[:return_code]}"
        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Failed', error: response[:return_code])
      end

      poa_form.save
    end

    private

    def enable_vbms_access?(poa_form:)
      poa_form.form_data['recordConsent'] && poa_form.form_data['consentLimits'].blank?
    end
  end
end
