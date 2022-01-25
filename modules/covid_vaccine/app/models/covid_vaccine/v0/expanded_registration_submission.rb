# frozen_string_literal: true

require 'json_marshal/marshaller'

module CovidVaccine
  module V0
    class ExpandedRegistrationSubmission < ApplicationRecord
      include AASM
      aasm(:state) do
        # Fire off job for email confirmation to the user that submission has been received
        # Fire off job to determine EMIS eligibility to kick off after hours; transition to eligible or ineligible
        state :received, initial: true
        state :enrollment_pending, :enrollment_complete, :enrollment_failed, :registered,
              :registered_no_icn, :registered_no_facility

        # Batch id is updated based on time that batch was submitted; transitions to enrollment_pending
        event :submitted_for_enrollment do
          transitions from: :received, to: :enrollment_pending
        end

        # submission is successfully sent to VeText without an ICN
        event :successful_registration_no_icn do
          transitions from: :enrollment_failed, to: :registered_no_icn
        end

        # submission is successfully sent to VeText without a facility match
        event :successful_registration_no_facility do
          transitions from: :enrollment_failed, to: :registered_no_facility
        end

        # Enrollment returned a success; transitions to enrollment_complete
        event :detected_enrollment do
          transitions from: :enrollment_pending, to: :enrollment_complete
        end

        # submission is successfully sent to VeText
        event :successful_registration do
          transitions from: :enrollment_complete, to: :registered
        end

        # Enrollment returned a failure; transitions to enrollment_failed
        event :failed_enrollment do
          transitions from: :enrollment_pending, to: :enrollment_failed
        end
      end

      after_initialize do |reg|
        reg.form_data&.symbolize_keys!
      end

      serialize :eligibility_info, JsonMarshal::Marshaller
      serialize :form_data, JsonMarshal::Marshaller
      serialize :raw_form_data, JsonMarshal::Marshaller
      has_kms_key
      encrypts :eligibility_info, :form_data, :raw_form_data, key: :kms_key, **lockbox_options
    end
  end
end
