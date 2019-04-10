# frozen_string_literal: true

require 'evss/service_exception'

module EVSS
  module DisabilityCompensationForm
    # Custom exception that maps EVSS 526 errors to error details defined in config/locales/exceptions.en.yml
    #
    class ServiceException < EVSS::ServiceException
      include SentryLogging

      ERROR_MAP = {
        serviceError: 'evss.external_service_unavailable',
        ServiceException: 'evss.external_service_unavailable',
        notEligible: 'evss.disability_compensation_form.not_eligible',
        InProcess: 'evss.disability_compensation_form.form_in_process',
        disabled: 'evss.disability_compensation_form.disabled',
        marshalError: 'evss.disability_compensation_form.marshall_error',
        startBatchJobError: 'evss.disability_compensation_form.start_batch_job_error',
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
        veteran: 'common.exceptions.validation_errors',
        MaxEPCode: 'evss.disability_compensation_form.max_ep_code',
        PIFInUse: 'evss.disability_compensation_form.pif_in_use'
      }.freeze

      def errors
        Array(
          Common::Exceptions::SerializableError.new(
            i18n_data.merge(source: 'EVSS::DisabilityCompensationForm::Service', meta: { messages: @messages })
          )
        )
      end

      private

      def i18n_key
        @key
      end
    end
  end
end
