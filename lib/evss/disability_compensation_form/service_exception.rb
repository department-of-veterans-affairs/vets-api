# frozen_string_literal: true

require 'common/exceptions/base_error'

module EVSS
  module DisabilityCompensationForm
    class ServiceException < Common::Exceptions::BaseError
      ERROR_MAP = {
        serviceError: 'evss.526.external_service_unavailable',
        ServiceException: 'evss.526.external_service_unavailable',
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

      attr_reader :key, :messages

      def initialize(original_body)
        @messages = original_body['messages']
        @key = error_key
        super
      end

      private

      def error_key
        # in case of multiple errors highest priority code is the one set for the http response
        key = ERROR_MAP.select { |k, _v| messages_has_key?(k) }
        return key.values.first unless key.empty?
        ERROR_MAP[:default]
      end

      def messages_has_key?(key)
        @messages.any? { |m| m['key'].include? key.to_s }
      end
    end
  end
end
