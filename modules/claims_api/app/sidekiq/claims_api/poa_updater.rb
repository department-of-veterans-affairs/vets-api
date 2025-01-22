# frozen_string_literal: true

require 'bgs'
require 'bgs_service/person_web_service'
require 'bgs_service/vet_record_web_service'

module ClaimsApi
  class PoaUpdater < ClaimsApi::ServiceBase
    def perform(power_of_attorney_id, rep_id = nil) # rubocop:disable Metrics/MethodLength
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      process = ClaimsApi::Process.find_or_create_by(processable: poa_form,
                                                     step_type: 'POA_UPDATE')
      process.update!(step_status: 'IN_PROGRESS')
      ssn = poa_form.auth_headers['va_eauth_pnid']

      file_number = find_by_ssn(ssn, poa_form)
      poa_code = extract_poa_code(poa_form.form_data)

      response = update_birls_record(file_number, ssn, poa_code, poa_form)

      if response[:return_code] == 'BMOD0001'
        # Clear out the error message if there were previous failures
        poa_form.vbms_error_message = nil if poa_form.vbms_error_message.present?

        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Success')

        ClaimsApi::VANotifyAcceptedJob.perform_async(poa_form.id, rep_id) if vanotify?(poa_form.auth_headers, rep_id)

        ClaimsApi::PoaVBMSUpdater.perform_async(poa_form.id)

        process.update!(step_status: 'SUCCESS')
      else
        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        poa_form.vbms_error_message = "BGS Error: update_birls_record failed with code #{response[:return_code]}"
        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Failed', error: response[:return_code])

        process.update!(step_status: 'FAILED')
      end

      poa_form.save
    end

    private

    def bgs_ext_service(poa_form)
      BGS::Services.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )
    end

    def person_web_service(poa_form)
      ClaimsApi::PersonWebService.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )
    end

    def vet_record_service(poa_form)
      ClaimsApi::VetRecordWebService.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )
    end

    def find_by_ssn(ssn, poa_form)
      if Flipper.enabled? :claims_api_use_person_web_service
        person_web_service(poa_form).find_by_ssn(ssn)[:file_nbr] # rubocop:disable Rails/DynamicFindBy
      else
        bgs_ext_service(poa_form).people.find_by_ssn(ssn)[:file_nbr] # rubocop:disable Rails/DynamicFindBy
      end
    end

    def update_birls_record(file_number, ssn, poa_code, poa_form)
      if Flipper.enabled? :claims_api_use_vet_record_service
        vet_record_service(poa_form).update_birls_record(
          file_number:,
          ssn:,
          poa_code:
        )
      else
        bgs_ext_service(poa_form).vet_record.update_birls_record(
          file_number:,
          ssn:,
          poa_code:
        )
      end
    end
  end
end
