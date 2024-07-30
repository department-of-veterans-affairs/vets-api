# frozen_string_literal: true

class DependentsSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :dependents

  attribute :persons do |object|
    next [object[:persons]] if object[:persons].instance_of?(Hash)

    object[:persons]
  end
end
