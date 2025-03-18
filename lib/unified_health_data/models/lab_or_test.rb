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
  end

  class Attributes
    include Vets::Model

    attribute :display, String
    attribute :test_code, String
    attribute :date_completed, String
    attribute :sample_site, String
    attribute :encoded_data, String
    attribute :location, String
    attribute :ordered_by, String
    attribute :observations, UnifiedHealthData::Observation, array: true
  end

  class LabOrTest
    include Vets::Model

    attribute :id, String
    attribute :type, String
    attribute :attributes, UnifiedHealthData::Attributes, array: false
  end
end
