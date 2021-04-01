# frozen_string_literal: true

module CovidVaccine
  module V0
    class ExpandedRegistrationSubmission < ApplicationRecord
      include AASM

      aasm(:state) do
        # Fire off job for email confirmation to the user that submission has been received
        # Fire off job to determine EMIS eligibility to kick off after hours; transition to eligible or ineligible
        state :received, initial: true
        state :eligible, :ineligible, :enrollment_pending, :enrollment_complete,
              :enrollment_failed, :registered

        # ICN and EMIS lookup both satisfactory or no lookup possible; transitions to eligible
        event :eligibility_passed do
          transitions from: :received, to: :eligible
        end

        # ICN and EMIS returns unsatisfatory eligibility results; transitions to ineligible
        event :eligibility_failed do
          transitions from: :received, to: :ineligible
        end

        # Batch id is updated based on time that batch was submitted; transitions to enrollment_pending
        event :submitted_for_enrollment do
          transitions from: :received, to: :enrollment_pending
        end

        # Enrollment returned a success; transitions to enrollment_complete
        event :detected_enrollment do
          transitions from: :enrollment_pending, to: :enrollment_complete
        end

        # Enrollment returned a failure; transitions to enrollment_failed
        event :failed_enrollment do
          transitions from: :enrollment_pending, to: :enrollment_failed
        end
      end

      after_initialize do |reg|
        reg.form_data&.symbolize_keys!
      end

      attr_encrypted :form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller
      attr_encrypted :raw_form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller
      attr_encrypted :eligibility_info, key: Settings.db_encryption_key, marshal: true,
                                        marshaler: JsonMarshal::Marshaller
    end
  end
end
