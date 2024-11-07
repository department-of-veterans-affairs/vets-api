# frozen_string_literal: true

require 'bgs'
require 'bgs_service/person_web_service'
require 'bgs_service/vet_record_service'

module ClaimsApi
  class PoaUpdater < ClaimsApi::ServiceBase
    def perform(power_of_attorney_id, rep = nil)
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)

      ssn = poa_form.auth_headers['va_eauth_pnid']
      file_number = get_file_number(ssn, poa_form)
      poa_code = extract_poa_code(poa_form.form_data)

      response = get_response(file_number, ssn, poa_code, poa_form)

      if response[:return_code] == 'BMOD0001'
        poa_form.status = ClaimsApi::PowerOfAttorney::UPDATED
        # Clear out the error message if there were previous failures
        poa_form.vbms_error_message = nil if poa_form.vbms_error_message.present?

        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Success')

        ClaimsApi::VANotifyJob.perform_async(poa_form.id, rep) if vanotify?(poa_form.auth_headers, rep)

        ClaimsApi::PoaVBMSUpdater.perform_async(poa_form.id) if enable_vbms_access?(poa_form: poa_form)
      else
        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        poa_form.vbms_error_message = "BGS Error: update_birls_record failed with code #{response[:return_code]}"
        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Failed', error: response[:return_code])
      end

      poa_form.save
    end

    private

    def vanotify?(auth_headers, rep)
      if Flipper.enabled?(:lighthouse_claims_api_v2_poa_va_notify)
        auth_headers.key?(ClaimsApi::V2::Veterans::PowerOfAttorney::BaseController::VA_NOTIFY_KEY) && rep.present?
      else
        false
      end
    end

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
      ClaimsApi::VetRecordService.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )
    end

    def get_file_number(ssn, poa_form)
      if Flipper.enabled? :claims_api_poa_updater_enables_local_bgs
        person_web_service(poa_form).find_by_ssn(ssn) # rubocop:disable Rails/DynamicFindBy
      else
        bgs_service.people.find_by_ssn(ssn)[:file_nbr] # rubocop:disable Rails/DynamicFindBy
      end
    end

    def get_response(file_number, ssn, poa_code, poa_form)
      if Flipper.enabled? :claims_api_poa_updater_enables_local_bgs
        vet_record_service(poa_form).update_birls_record(
          file_number:,
          ssn:,
          poa_code:
        )
      else
        bgs_service.vet_record.update_birls_record(
          file_number:,
          ssn:,
          poa_code:
        )
      end
    end
  end
end
