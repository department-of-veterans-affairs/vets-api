# frozen_string_literal: true

require 'digest'

class EligibleDataClassesSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type 'eligible_data_classes'

  attribute :data_classes do |object|
    object.map(&:name)
  end
end
