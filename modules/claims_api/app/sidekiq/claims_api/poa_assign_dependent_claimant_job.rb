# frozen_string_literal: true

module ClaimsApi
  class PoaAssignDependentClaimantJob < ClaimsApi::ServiceBase
    LOG_TAG = 'poa_assign_dependent_claimant_job'

    sidekiq_options retry_for: 48.hours

    def perform(poa_id, rep_id = nil) # rubocop:disable Metrics/MethodLength
      poa = ClaimsApi::PowerOfAttorney.find(poa_id)
      poa_code = extract_poa_code(poa.form_data)

      service = dependent_claimant_poa_assignment_service(
        poa.id,
        poa.form_data,
        poa.auth_headers
      )

      ClaimsApi::Logger.log(
        LOG_TAG,
        poa_id: poa.id,
        detail: form_logger_consent_detail(poa, poa_code),
        poa_code:,
        allow_poa_access: allow_poa_access?(poa_form_data: poa.form_data),
        allow_poa_c_add: allow_address_change?(poa)
      )

      begin
        service.assign_poa_to_dependent!

        poa.status = ClaimsApi::PowerOfAttorney::UPDATED
        # Clear out the error message if there were previous failures
        poa.vbms_error_message = nil if poa.vbms_error_message.present?

        poa.save

        log_job_progress(
          poa.id,
          'POA assigned for dependent'
        )

        ClaimsApi::VANotifyAcceptedJob.perform_async(poa.id, rep_id) if vanotify?(poa.auth_headers, rep_id)
      rescue => e
        handle_error(poa, e)
      end
    end

    private

    def handle_error(poa, e)
      save_poa_errored_state(poa)
      set_vbms_error_message(poa, e)
      log_job_progress(
        poa.id,
        'Dependent Assignment failed'
      )
      raise e
    end

    def dependent_claimant_poa_assignment_service(poa_id, form_data, auth_headers)
      ClaimsApi::DependentClaimantPoaAssignmentService.new(
        poa_id:,
        poa_code: extract_poa_code(form_data),
        veteran_participant_id: auth_headers['va_eauth_pid'],
        dependent_participant_id: auth_headers.dig('dependent', 'participant_id'),
        veteran_file_number: auth_headers['file_number'],
        allow_poa_access: allow_poa_access?(poa_form_data: form_data) ? 'Y' : 'N',
        allow_poa_cadd: form_data['consentAddressChange'].present? ? 'Y' : nil,
        claimant_ssn: auth_headers.dig('dependent', 'ssn')
      )
    end
  end
end
