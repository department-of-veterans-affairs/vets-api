# frozen_string_literal: true

class EligibilitySerializer
  include JSONAPI::Serializer

  set_id { '' }
  attributes :eligibility
end
