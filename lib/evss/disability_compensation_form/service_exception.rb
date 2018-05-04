# frozen_string_literal: true

require 'evss/service_exception'

module EVSS
  module DisabilityCompensationForm
    class ServiceException < EVSS::ServiceException
      ERROR_MAP = {
        serviceError: 'evss.external_service_unavailable',
        ServiceException: 'evss.external_service_unavailable',
        notEligible: 'evss.526.not_eligible',
        InProcess: 'evss.526.form_in_process',
        disabled: 'evss.526.disabled',
        marshalError: 'evss.526.marshall_error',
        startBatchJobError: 'evss.526.start_batch_job_error',
        Size: 'common.exceptions.validation_errors',
        Pattern: 'common.exceptions.validation_errors',
        NotNull: 'common.exceptions.validation_errors',
        header: 'common.exceptions.validation_errors',
        ActiveDuty13BirthDate: 'common.exceptions.validation_errors',
        DisabilityDuplicate: 'common.exceptions.validation_errors',
        TreatmentPastActiveDutyDate: 'common.exceptions.validation_errors',
        AttachmentType: 'common.exceptions.validation_errors',
        directDeposit: 'common.exceptions.validation_errors',
        disabilities: 'common.exceptions.validation_errors',
        militaryPayments: 'common.exceptions.validation_errors',
        serviceInformation: 'common.exceptions.validation_errors',
        treatments: 'common.exceptions.validation_errors',
        veteran: 'common.exceptions.validation_errors'
      }.freeze
    end
  end
end
