# frozen_string_literal: true

require 'vets/model'

module UnifiedHealthData
  class ObservationValue
    include Vets::Model

    attribute :text, String
    attribute :type, String
  end

  class Observation
    include Vets::Model

    attribute :test_code, String
    attribute :value, UnifiedHealthData::ObservationValue
    attribute :reference_range, String
    attribute :status, String
    attribute :comments, String
    attribute :body_site, String
    attribute :sample_tested, String
  end

  class LabOrTest
    include Vets::Model

    attribute :id, String
    attribute :type, String
    attribute :display, String
    attribute :test_code, String
    attribute :test_code_display, String
    attribute :date_completed, String
    attribute :sort_date, String # Normalized date for sorting (internal use only)
    attribute :sample_tested, String
    attribute :encoded_data, String
    attribute :location, String
    attribute :ordered_by, String
    attribute :body_site, String
    attribute :status, String
    attribute :source, String
    attribute :observations, UnifiedHealthData::Observation, array: true

    default_sort_by sort_date: :desc
  end
end
