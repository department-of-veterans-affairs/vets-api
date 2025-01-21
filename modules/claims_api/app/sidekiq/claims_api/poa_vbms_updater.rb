# frozen_string_literal: true

require 'bgs'
require 'bgs_service/corporate_update_web_service'

module ClaimsApi
  class PoaVBMSUpdater < ClaimsApi::ServiceBase
    def perform(power_of_attorney_id) # rubocop:disable Metrics/MethodLength
      poa_form = ClaimsApi::PowerOfAttorney.find(power_of_attorney_id)
      process = ClaimsApi::Process.find_or_create_by(processable: poa_form, step_type: 'POA_ACCESS_UPDATE')
      process.update!(step_status: 'IN_PROGRESS')
      @external_uid = poa_form.external_uid
      @external_key = poa_form.external_key
      poa_code = extract_poa_code(poa_form.form_data)

      ClaimsApi::Logger.log(
        'poa_vbms_updater',
        poa_id: power_of_attorney_id,
        detail: 'Updating Access',
        poa_code:,
        allow_poa_access: enable_vbms_access?(poa_form:),
        allow_poa_c_add: allow_address_change?(poa_form)
      )

      response = update_poa_access(poa_form:, participant_id: poa_form.auth_headers['va_eauth_pid'],
                                   poa_code:)

      if response[:return_code] == 'GUIE50000'
        poa_form.status = ClaimsApi::PowerOfAttorney::UPDATED
        process.update!(step_status: 'SUCCESS')
        poa_form.vbms_error_message = nil if poa_form.vbms_error_message.present?
        ClaimsApi::Logger.log('poa_vbms_updater', poa_id: power_of_attorney_id, detail: 'VBMS Success')
      else
        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        poa_form.vbms_error_message = 'update_poa_access failed with code ' \
                                      "#{response[:return_code]}: #{response[:return_message]}"
        poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
        process.update!(step_status: 'FAILED')
        ClaimsApi::Logger.log('poa_vbms_updater',
                              poa_id: power_of_attorney_id,
                              detail: 'VBMS Failed',
                              error: response[:return_message])
      end

      poa_form.save
    rescue BGS::ShareError => e
      poa_form.status = ClaimsApi::PowerOfAttorney::ERRORED
      process.update!(step_status: 'FAILED')
      poa_form.vbms_error_message = e.respond_to?(:message) ? e.message : 'BGS::ShareError'
      poa_form.save
      ClaimsApi::Logger.log('poa', poa_id: poa_form.id, detail: 'BGS Error', error: e)
    end

    def allow_address_change?(poa_form)
      poa_form.form_data['consentAddressChange']
    end

    def update_poa_access(poa_form:, participant_id:, poa_code:)
      # allow_poa_c_add reports 'No Data' if sent lowercase
      service = if Flipper.enabled? :claims_api_poa_vbms_updater_uses_local_bgs
                  corporate_update_service
                else
                  bgs_ext_service.corporate_update
                end
      service.update_poa_access(
        participant_id:,
        poa_code:,
        allow_poa_access: enable_vbms_access?(poa_form:) ? 'Y' : 'N',
        allow_poa_c_add: allow_address_change?(poa_form) ? 'Y' : 'N'
      )
    end

    def corporate_update_service
      ClaimsApi::CorporateUpdateWebService.new(
        external_uid: @external_uid,
        external_key: @external_key
      )
    end

    def bgs_ext_service
      BGS::Services.new(
        external_uid: @external_uid,
        external_key: @external_key
      )
    end
  end
end
