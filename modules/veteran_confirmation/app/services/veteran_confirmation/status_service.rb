# frozen_string_literal: true

require 'ostruct'
require 'emis/veteran_status_service'

module VeteranConfirmation
  class StatusService
    CONFIRMED = 'confirmed'
    NOT_CONFIRMED = 'not confirmed'

    # request state
    PENDING_COMPLETION = 'PENDING_COMPLETION'
    REQUEST_COMPLETED = 'REQUEST_COMPLETED'
    CALL_TO_MPI_FAILED = 'CALL_TO_MPI_FAILED'
    CALL_TO_EMIS_FAILED = 'CALL_TO_EMIS_FAILED'
    FAILED_DUE_TO_EXCEPTION = 'FAILED_DUE_TO_EXCEPTION'
    PERSON_NOT_FOUND = 'PERSON_NOT_FOUND'
    FAILED_DUE_TO_MISSING_DATA = 'FAILED_DUE_TO_MISSING_DATA'

    # request result
    COMPLETED_CONFIRMED = 'COMPLETED_CONFIRMED'
    COMPLETED_NOT_CONFIRMED = 'COMPLETED_NOT_CONFIRMED'
    ERROR = 'ERROR'
    PENDING = 'PENDING'

    def get_mvi_resp(user_attributes)
      MPI::Service.new.find_profile_by_attributes(ssn: user_attributes[:ssn],
                                                  first_name: user_attributes[:first_name],
                                                  last_name: user_attributes[:last_name],
                                                  birth_date: user_attributes[:birth_date])
    end

    def get_by_attributes(user_attributes)
      mvi_resp = get_mvi_resp(user_attributes)
      status_request_id = SecureRandom.uuid
      log_request_state(status_request_id, PENDING_COMPLETION, PENDING, 'Veteran status request received')
      if mvi_resp.not_found?
        log_request_state(status_request_id, PERSON_NOT_FOUND, COMPLETED_NOT_CONFIRMED, 'Person not found in MPI')
        return NOT_CONFIRMED
      end
      unless mvi_resp.ok?
        log_request_state(status_request_id, CALL_TO_MPI_FAILED, ERROR, 'call to MPI did not return 200')
        raise mvi_resp.error
      end
      veteran_status_service = get_veteran_status_service
      emis_resp = veteran_status_service.get_veteran_status(edipi_or_icn_option(mvi_resp.profile))
      if emis_resp.error?
        log_request_state(status_request_id, CALL_TO_EMIS_FAILED, COMPLETED_NOT_CONFIRMED, 'EMIS did not return 200')
        return NOT_CONFIRMED
      end
      determine_if_confirmed(emis_resp, status_request_id)
    end

    private

    def log_request_state(uuid, state, result, msg)
      Rails.logger.info("[STATUS-REQUEST][id=#{uuid}][state-of-request:#{state}][result:#{result}]: #{msg}")
    end

    def get_veteran_status_service
      veteran_status_service = nil
      if Settings.vet_verification.mock_emis == true
        Rails.logger.info("Settings.vet_verification.mock_emis: #{Settings.vet_verification.mock_emis}")
        veteran_status_service = EMIS::MockVeteranStatusService.new
      else
        veteran_status_service = EMIS::VeteranStatusService.new
      end

      Rails.logger.info("Service type: #{veteran_status_service}")
      veteran_status_service
    end

    def determine_if_confirmed(emis_resp, status_request_id)
      if emis_resp.items.first&.title38_status_code == 'V1'
        msg = 'call to va profile status endpoint succeeded. veteran confirmation status: CONFIRMED'
        log_request_state(status_request_id, REQUEST_COMPLETED, COMPLETED_CONFIRMED, msg)
        CONFIRMED
      else
        msg = 'call to va profile status endpoint succeeded. veteran confirmation status: NOT_CONFIRMED'
        log_request_state(status_request_id, REQUEST_COMPLETED, COMPLETED_NOT_CONFIRMED, msg)
        NOT_CONFIRMED
      end
    end

    def edipi_or_icn_option(profile)
      if profile.edipi.present?
        { edipi: profile.edipi }
      else
        { icn: profile.icn }
      end
    end
  end
end
