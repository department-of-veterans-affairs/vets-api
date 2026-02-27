# frozen_string_literal: true

module UnifiedHealthData
  class LabOrTestSerializer
    include JSONAPI::Serializer

    set_id :id
    set_type 'DiagnosticReport'

    attributes :display,
               :test_code,
               :test_code_display,
               :date_completed,
               :sample_tested,
               :encoded_data,
               :location,
               :ordered_by,
               :body_site,
               :comments,
               :status,
               :source,
               :facility_timezone,
               :observations
  end
end
