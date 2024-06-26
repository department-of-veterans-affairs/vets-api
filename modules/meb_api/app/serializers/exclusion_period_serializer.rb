# frozen_string_literal: true

class ExclusionPeriodSerializer
  include JSONAPI::Serializer

  attribute :exclusion_periods

  set_id { '' }
end
