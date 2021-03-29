# frozen_string_literal: true

module CovidVaccine
  module V0
    class ExpandedRegistrationSubmission < ApplicationRecord
      # Processing States
      SEQUESTERED = 'sequestered'
      INELIGIBLE = 'ineligible'
      ENROLLMENT_PENDING = 'enrollment_pending'
      ENROLLMENT_COMPLETE = 'enrollment_complete'
      ENROLLMENT_FAILED = 'enrollment_failed'
      REGISTERED = 'registered'

      after_initialize do |reg|
        reg.form_data&.symbolize_keys!
      end

      after_find do |reg|
        reg.raw_form_data&.symbolize_keys!
      end


      attr_encrypted :form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller
      attr_encrypted :raw_form_data, key: Settings.db_encryption_key, marshal: true, marshaler: JsonMarshal::Marshaller
      attr_encrypted :eligibility_info, key: Settings.db_encryption_key, marshal: true,
                                        marshaler: JsonMarshal::Marshaller
    end
  end
end
