# frozen_string_literal: true

class CemeterySerializer
  include JSONAPI::Serializer

  set_type :preneeds_cemeteries

  attribute :name
  attribute :cemetery_type
  attribute :num

  attributes :cemetery_id do |object|
    object.id
  end
end
