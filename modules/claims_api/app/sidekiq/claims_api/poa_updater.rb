# frozen_string_literal: true

require 'bgs'

module ClaimsApi
  class PoaUpdater < ClaimsApi::ServiceBase
    def perform(power_of_attorney_id) # rubocop:disable Metrics/MethodLength
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      service = BGS::Services.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )

      ssn = poa_form.auth_headers['va_eauth_pnid']
      file_number = service.people.find_by_ssn(ssn)[:file_nbr] # rubocop:disable Rails/DynamicFindBy

      poa_code = extract_poa_code(poa_form.form_data)

      unless poa_code.nil?
        response = service.vet_record.update_birls_record(
          file_number:,
          ssn:,
          poa_code:
        )
      end

      if response && response[:return_code] == 'BMOD0001'
        poa_form.status = ClaimsApi::PowerOfAttorney::UPDATED
        # Clear out the error message if there were previous failures
        poa_form.vbms_error_message = nil if poa_form.vbms_error_message.present?

        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Success')

        ClaimsApi::PoaVBMSUpdater.perform_async(poa_form.id) if enable_vbms_access?(poa_form:)
      else
        error_response = set_error_message(response, power_of_attorney_id)

        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        poa_form.vbms_error_message = error_response
        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Failed', error: error_response)
      end

      poa_form.save
    end

    private

    def extract_poa_code(poa_form_data)
      if poa_form_data.key?('serviceOrganization')
        poa_form_data['serviceOrganization']['poaCode']
      elsif poa_form_data.key?('representative') # V2 2122a
        poa_form_data['representative']['poaCode']
      end
    end

    def set_error_message(response, power_of_attorney_id)
      if response&.[](:return_code)
        "BGS Error: update_birls_record failed with code #{response[:return_code]}"
      else
        "No POA code found in form #{power_of_attorney_id}"
      end
    end

    def enable_vbms_access?(poa_form:)
      poa_form.form_data['recordConsent'] && poa_form.form_data['consentLimits'].blank?
    end
  end
end
