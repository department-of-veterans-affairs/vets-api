# frozen_string_literal: true

module UnifiedHealthData
  class LabOrTestSerializer
    include JSONAPI::Serializer

    set_id :id
    # TODO: should this be 'lab_or_test' so it matches the model name?
    set_type 'DiagnosticReport'

    attributes :display,
               :test_code,
               :date_completed,
               :sample_tested,
               :encoded_data,
               :location,
               :ordered_by,
               :body_site,
               :observations
  end
end
