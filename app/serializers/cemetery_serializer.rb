# frozen_string_literal: true

class CemeterySerializer
  include JSONAPI::Serializer

  set_type :preneeds_cemeteries

  attribute :name
  attribute :cemetery_type
  attribute :num
  attribute :cemetery_id, &:id
end
