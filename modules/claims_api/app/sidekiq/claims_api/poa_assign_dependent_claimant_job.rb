# frozen_string_literal: true

module ClaimsApi
  class PoaAssignDependentClaimantJob < ClaimsApi::ServiceBase
    LOG_TAG = 'poa_assign_dependent_claimant_job'

    def perform(poa_id, rep)
      poa = ClaimsApi::PowerOfAttorney.find(poa_id)

      service = dependent_claimant_poa_assignment_service(
        poa.id,
        poa.form_data,
        poa.auth_headers
      )

      begin
        service.assign_poa_to_dependent!
      rescue => e
        handle_error(poa, e)
      end

      poa.status = ClaimsApi::PowerOfAttorney::UPDATED
      # Clear out the error message if there were previous failures
      poa.vbms_error_message = nil if poa.vbms_error_message.present?

      poa.save

      log_job_progress(
        poa.id,
        'POA assigned for dependent'
      )

      ClaimsApi::VANotifyAcceptedJob.perform_async(poa.id, rep) if vanotify?(poa.auth_headers, rep)
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

    def dependent_claimant_poa_assignment_service(poa_id, data, auth_headers)
      ClaimsApi::DependentClaimantPoaAssignmentService.new(
        poa_id:,
        poa_code: find_poa_code(data),
        veteran_participant_id: auth_headers['va_eauth_pid'],
        dependent_participant_id: auth_headers.dig('dependent', 'participant_id'),
        veteran_file_number: auth_headers['file_number'],
        allow_poa_access: data['recordConsent'].present? ? 'Y' : nil,
        allow_poa_cadd: data['consentAddressChange'].present? ? 'Y' : nil,
        claimant_ssn: auth_headers.dig('dependent', 'ssn')
      )
    end

    def find_poa_code(data)
      base = data.key?('serviceOrganization') ? 'serviceOrganization' : 'representative'
      data.dig(base, 'poaCode')
    end
  end
end
