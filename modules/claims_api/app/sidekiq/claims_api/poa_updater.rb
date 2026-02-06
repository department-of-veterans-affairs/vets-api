# frozen_string_literal: true

require 'bgs'
require 'bgs_service/person_web_service'
require 'bgs_service/vet_record_web_service'
require 'bgs_service/manage_representative_service'

module ClaimsApi
  class PoaUpdater < ClaimsApi::ServiceBase
    sidekiq_options retry_for: 48.hours

    def perform(power_of_attorney_id, rep_id = nil) # rubocop:disable Metrics/MethodLength
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)

      process = ClaimsApi::Process.find_or_create_by(processable: poa_form,
                                                     step_type: 'POA_UPDATE')
      process.update!(step_status: 'IN_PROGRESS')
      ssn = poa_form.auth_headers['va_eauth_pnid']

      file_number = find_by_ssn(ssn, poa_form)
      poa_code = extract_poa_code(poa_form.form_data)

      response = update_birls_record(file_number, ssn, poa_code, poa_form)

      # handle response failures
      if response_is_successful?(response)
        # Clear out the error message if there were previous failures
        poa_form.vbms_error_message = nil if poa_form.vbms_error_message.present?
        poa_form.save
        process.update!(step_status: 'SUCCESS', error_messages: [], completed_at: Time.zone.now)

        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Success')

        ClaimsApi::PoaVBMSUpdater.perform_async(poa_form.id, rep_id)
      else
        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        poa_form.vbms_error_message = "BGS Error: update_birls_record failed with code #{response[:return_code]}"
        poa_form.save
        process.update!(step_status: 'FAILED',
                        error_messages: [{ title: 'BGS Error',
                                           detail: poa_form.vbms_error_message }])
        ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BIRLS Failed', error: response[:return_code])
      end

    # handle exceptions thrown from soap_error_handler.rb with requests to BGS
    rescue ::Common::Exceptions::ResourceNotFound, ::Common::Exceptions::ServiceError,
           ::Common::Exceptions::UnprocessableEntity => e
      rescue_generic_errors(poa_form, e) if poa_form
      process&.update!(step_status: 'FAILED',
                       error_messages: [{ title: 'BGS Error', detail: e.errors&.first&.detail || e.message }])
      # raise error to trigger sidekiq retry mechanism
      raise
    rescue => e
      rescue_generic_errors(poa_form, e) if poa_form
      process&.update!(step_status: 'FAILED',
                       error_messages: [{ title: 'Generic Error', detail: e.message }])
      # raise error to trigger sidekiq retry mechanism
      raise
    end

    private

    def response_is_successful?(response)
      if Flipper.enabled?(:claims_api_use_update_poa_relationship)
        response['dateRequestAccepted'].present?
      else
        response[:return_code] == 'BMOD0001'
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
      ClaimsApi::VetRecordWebService.new(
        external_uid: poa_form.external_uid,
        external_key: poa_form.external_key
      )
    end

    def manage_rep_poa_update_service(poa_form)
      ClaimsApi::ManageRepresentativeService.new(
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
      if Flipper.enabled?(:claims_api_use_update_poa_relationship)
        manage_rep_poa_update_service(poa_form).update_poa_relationship(
          pctpnt_id: poa_form.auth_headers['va_eauth_pid'],
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
